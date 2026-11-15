// android/app/src/main/kotlin/com/recoveryforall/atlas/AtlasNativeBridge.kt
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

package com.recoveryforall.atlas

import android.content.Context
import com.intellitrip.domain.FeedId
import com.intellitrip.domain.FeedMetadata
import com.intellitrip.domain.GeoPoint
import com.intellitrip.domain.JourneyOption
import com.intellitrip.domain.Leg
import com.intellitrip.domain.StopKey
import com.intellitrip.domain.TransferConfidence
import com.intellitrip.domain.TripKey
import com.intellitrip.domain.TripPlanRequest
import com.intellitrip.engine.AtlasEngine
import com.intellitrip.engine.AtlasProviders
import com.intellitrip.engine.JourneyOutcome
import com.intellitrip.gtfs.GtfsFeedAcquirer
import com.intellitrip.gtfs.InMemoryStaticTransitProvider
import com.intellitrip.gtfs.PlatformFileStore
import com.intellitrip.gtfs.RefreshOutcome
import com.intellitrip.gtfs.StaticFeed
import com.intellitrip.gtfs.StaticFeedRefresher
import com.intellitrip.gtfs.StaticFeedSnapshotStore
import com.intellitrip.offline.JvmOfflineSnapshotPort
import com.intellitrip.offline.OfflineRegistry
import com.intellitrip.offline.loadStaticFeed
import com.intellitrip.routing.RoutingNetwork
import com.intellitrip.routing.StaticNetworkPlanner
import com.intellitrip.routing.StopTimeSource
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.coroutineContext
import kotlin.time.Duration.Companion.days
import kotlin.time.Duration.Companion.minutes
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlinx.datetime.toLocalDateTime

/** Single-completion bridge result seam for Flutter MethodChannel and JVM tests. */
internal interface BridgeResult {
    fun success(value: Any?)
    fun error(code: String, message: String?, details: Any?)
}

internal class SingleReplyBridgeResult(
    private val delegate: BridgeResult,
) : BridgeResult {
    private val replied = AtomicBoolean(false)

    override fun success(value: Any?) {
        if (replied.compareAndSet(false, true)) {
            delegate.success(value)
        }
    }

    override fun error(code: String, message: String?, details: Any?) {
        if (replied.compareAndSet(false, true)) {
            delegate.error(code, message, details)
        }
    }
}

private fun MethodChannel.Result.asSingleReply(): BridgeResult = SingleReplyBridgeResult(
    object : BridgeResult {
        override fun success(value: Any?) = this@asSingleReply.success(value)
        override fun error(code: String, message: String?, details: Any?) =
            this@asSingleReply.error(code, message, details)
    },
)

/**
 * API-26+ implementation of `recoveryforall/atlas_v1`.
 *
 * The bundled static GTFS snapshot is the offline default. Network acquisition
 * runs ONLY when explicitly requested via `refreshStaticFeed` after user
 * privacy consent; no implicit feed downloads happen at startup or during
 * journey planning.
 */
internal class AtlasNativeBridge internal constructor(
    private val context: Context?,
    private val clock: () -> Instant = { Clock.System.now() },
    private val plannerDispatcher: CoroutineDispatcher = Dispatchers.Default,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val mainDispatcher: CoroutineDispatcher = Dispatchers.Main,
    private val feedSourceUrl: String = DEFAULT_FEED_SOURCE_URL,
    private val snapshotStoreOverride: StaticFeedSnapshotStore? = null,
    private val bundledAssetOpener: (() -> ByteArray)? = null,
    private val httpTransportFactory: (() -> GtfsFeedAcquirer.HttpTransport)? = null,
) : AtlasChannelAdapter.Delegate {

    constructor(context: Context) : this(context = context, clock = { Clock.System.now() })

    private companion object {
        const val DEFAULT_FEED_ID = "metro-transit-regional"
        const val ASSET_PATH = "gtfs/metro_transit_regional.zip"
        const val ASSET_SOURCE_URL = "asset://gtfs/metro_transit_regional.zip"
        const val DEFAULT_FEED_SOURCE_URL = "https://svc.metrotransit.org/mtgtfs/gtfs.zip"
        const val USER_AGENT = "RecoveryForAll/1.0 (Android; Atlas-Bridge)"
        const val ROUTING_PROVIDER_ID = "atlas_static_planner"
        const val DEFAULT_PLAN_TIMEOUT_MS = 12_000L
        const val MAX_PLAN_TIMEOUT_MS = 60_000L
        const val MAX_TRACKED_REQUEST_IDS = 512

        val NO_STOP_COVERAGE_REASONS = setOf(
            "stops-within-walk-limit",
            "no-origin-stops-within-walk-limit",
            "no-destination-stops-within-walk-limit",
        )

        /**
         * Capture time of the bundled snapshot, not the time the app launched.
         *
         * The asset's calendars cover 2026-11-14 through 2027-01-01; this is
         * the snapshot timestamp. Update it with the asset and its
         * PROVENANCE.txt in the same commit.
         */
        val BUNDLED_FEED_CAPTURED_AT: Instant = Instant.parse("2026-11-14T08:55:36Z")

        val AGENCY_ZONE: TimeZone = TimeZone.of("America/Chicago")
    }

    private class InFlightRequest(
        val canceledByCaller: AtomicBoolean = AtomicBoolean(false),
    ) {
        lateinit var job: Job
    }

    private val scope = CoroutineScope(SupervisorJob() + plannerDispatcher)
    private val initMutex = Mutex()
    private val requestLock = Any()
    private val inFlight = HashMap<String, InFlightRequest>()
    private val preCanceled = LinkedHashSet<String>()
    private val terminalRequests = LinkedHashSet<String>()

    @Volatile
    private var atlasEngine: AtlasEngine? = null

    @Volatile
    private var routingNetwork: RoutingNetwork? = null

    @Volatile
    private var initFailure: String? = null

    private val feedId = FeedId(DEFAULT_FEED_ID)

    private val snapshotStore: StaticFeedSnapshotStore by lazy {
        snapshotStoreOverride ?: StaticFeedSnapshotStore(
            PlatformFileStore(requireNotNull(context).filesDir.absolutePath),
        )
    }

    private val offlineRegistry: OfflineRegistry by lazy {
        OfflineRegistry(JvmOfflineSnapshotPort(snapshotStore))
    }

    /** Warms the local snapshot without blocking the Flutter platform thread. */
    fun initAsync() {
        scope.launch(ioDispatcher) {
            try {
                ensureEngine(feedId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                initFailure = "init_failed"
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        dispatchMethod(call.method, args, result.asSingleReply())
    }

    internal fun dispatchMethod(
        method: String,
        arguments: Map<*, *>?,
        result: BridgeResult,
    ) {
        val reply = SingleReplyBridgeResult(result)
        when (method) {
            "getCapabilities" -> reply.success(capabilities())
            "loadStaticNetwork" -> handleLoadStaticNetwork(arguments, reply)
            "planJourney" -> handlePlanJourney(arguments, reply)
            "cancelRequest" -> handleCancelRequest(arguments, reply)
            "getOfflineStatus" -> handleOfflineStatus(arguments, reply)
            "refreshStaticFeed" -> handleRefreshStaticFeed(arguments, reply)
            "getWeather" -> reply.success(mapOf("status" to "unsupported"))
            else -> reply.error("UNSUPPORTED_METHOD", "Unsupported method: $method", null)
        }
    }

    private fun Map<*, *>?.stringArg(key: String): String? = this?.get(key) as? String
    private fun Map<*, *>?.boolArg(key: String): Boolean? = this?.get(key) as? Boolean
    private fun Map<*, *>?.numberArg(key: String): Number? = this?.get(key) as? Number
    private fun Map<*, *>?.mapArg(key: String): Map<*, *>? = this?.get(key) as? Map<*, *>
    private fun Map<*, *>?.listArg(key: String): List<*>? = this?.get(key) as? List<*>

    private fun capabilities(): Map<String, Any?> {
        val engine = atlasEngine
        val network = routingNetwork
        val usable = engine != null &&
            network != null &&
            !isFeedExpired(network.metadata, clock())
        val hasRouting = usable && engine.providers.routing != null
        val hasStatic = usable && engine.providers.transitStatic != null
        return mapOf(
            "version" to AtlasChannelAdapter.CURRENT_API_VERSION,
            "staticTransit" to hasStatic,
            "localRouting" to hasRouting,
            "realtime" to false,
            "weather" to false,
            "offlineSnapshot" to (network != null),
            "providerIds" to if (hasRouting) listOf(ROUTING_PROVIDER_ID) else emptyList<String>(),
        )
    }

    private fun handleLoadStaticNetwork(arguments: Map<*, *>?, reply: BridgeResult) {
        val requested = arguments.stringArg("feedId")?.takeIf { it.isNotBlank() } ?: DEFAULT_FEED_ID
        val target = if (requested == "default") feedId else FeedId(requested)
        val fromCacheOnly = arguments.boolArg("fromCacheOnly") ?: true

        if (target != feedId) {
            reply.success(missingStatus("unsupported_feed"))
            return
        }

        scope.launch(ioDispatcher) {
            try {
                val engine = ensureEngine(target)
                val network = routingNetwork
                if (engine == null || network == null) {
                    sendSuccess(reply, missingStatus(failureSource(fromCacheOnly)))
                    return@launch
                }

                sendSuccess(reply, statusMapForNetwork(network))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                sendError(reply, "NATIVE_FAILURE", "Failed to load static network: ${e.message}", null)
            }
        }
    }

    private fun reqHash(requestId: String): String = requestId.hashCode().toUInt().toString(16)

    private fun logInfo(message: String) {
        if (context != null) {
            runCatching { android.util.Log.i("AtlasNativeBridge", message) }
        }
    }

    private fun recordTerminalLocked(requestId: String) {
        terminalRequests.remove(requestId)
        terminalRequests.add(requestId)
        while (terminalRequests.size > MAX_TRACKED_REQUEST_IDS) {
            val oldest = terminalRequests.first()
            terminalRequests.remove(oldest)
        }
    }

    private fun markPreCanceledLocked(requestId: String) {
        preCanceled.remove(requestId)
        preCanceled.add(requestId)
        while (preCanceled.size > MAX_TRACKED_REQUEST_IDS) {
            val oldest = preCanceled.first()
            preCanceled.remove(oldest)
        }
    }

    private fun statusMapForNetwork(network: RoutingNetwork, sourceOverride: String? = null): Map<String, Any?> {
        val metadata = network.metadata
        val expired = isFeedExpired(metadata, clock())
        val source = sourceOverride ?: if (metadata.sourceUrl?.startsWith("asset:") == true) {
            "bundled_asset"
        } else {
            "static_gtfs"
        }
        return mapOf(
            "state" to if (expired) "expired" else "ready",
            "feedHash" to metadata.hash,
            "fetchedAt" to metadata.fetchedAt.toEpochMilliseconds(),
            "expiresAt" to expiresAtUtcMs(metadata),
            "stopCount" to network.stops.size,
            "source" to source,
        )
    }

    private fun handlePlanJourney(arguments: Map<*, *>?, reply: BridgeResult) {
        val requestId = arguments.stringArg("requestId")?.trim().orEmpty()
        if (requestId.isEmpty()) {
            reply.error("BAD_INPUT", "requestId must not be empty", null)
            return
        }

        val allowRemote = arguments.boolArg("allowRemote") ?: false
        if (allowRemote) {
            reply.error(
                "REMOTE_DISABLED",
                "Remote routing is disabled in this build; only the bundled static planner is available.",
                mapOf("requestId" to requestId),
            )
            return
        }

        val modes = arguments.listArg("transitModes")
            ?.mapNotNull { it as? String }
            ?.toSet()
        if (modes != null && (modes.isEmpty() || modes.any { it !in setOf("bus", "rail") })) {
            reply.error(
                "BAD_INPUT",
                "transitModes must contain 'bus' and/or 'rail'",
                mapOf("requestId" to requestId),
            )
            return
        }

        val meetingId = arguments.stringArg("meetingId") ?: ""
        val originMap = arguments.mapArg("origin")
        val destinationMap = arguments.mapArg("destination")
        val originLat = (originMap?.get("lat") as? Number)?.toDouble()
        val originLon = (originMap?.get("lon") as? Number)?.toDouble()
        val destLat = (destinationMap?.get("lat") as? Number)?.toDouble()
        val destLon = (destinationMap?.get("lon") as? Number)?.toDouble()

        if (originLat == null || originLon == null || destLat == null || destLon == null) {
            reply.error("BAD_INPUT", "Missing origin or destination coordinates", null)
            return
        }
        if (!isValidCoordinate(originLat, originLon) || !isValidCoordinate(destLat, destLon)) {
            reply.error(
                "BAD_INPUT",
                "Coordinates out of bounds: origin($originLat, $originLon), dest($destLat, $destLon)",
                null,
            )
            return
        }

        val maxWalkMeters = arguments.numberArg("maxWalkMeters")?.toInt() ?: 1500
        if (maxWalkMeters < 0) {
            reply.error("BAD_INPUT", "maxWalkMeters must not be negative", null)
            return
        }

        val departAtUtcMs = arguments.numberArg("departAtUtcMs")?.toLong() ?: clock().toEpochMilliseconds()
        val arriveBeforeUtcMs = arguments.numberArg("arriveBeforeUtcMs")?.toLong()
        val timeoutMs = (arguments.numberArg("timeoutMs")?.toLong() ?: DEFAULT_PLAN_TIMEOUT_MS)
            .coerceIn(1L, MAX_PLAN_TIMEOUT_MS)

        val entry = InFlightRequest()
        val job = scope.launch(plannerDispatcher, start = CoroutineStart.LAZY) {
            executePlanJourney(
                requestId = requestId,
                meetingId = meetingId,
                originLat = originLat,
                originLon = originLon,
                destLat = destLat,
                destLon = destLon,
                maxWalkMeters = maxWalkMeters,
                departAtUtcMs = departAtUtcMs,
                arriveBeforeUtcMs = arriveBeforeUtcMs,
                timeoutMs = timeoutMs,
                entry = entry,
                reply = reply,
            )
        }
        entry.job = job

        var duplicateInFlight = false
        var canceledBeforeStart = false
        synchronized(requestLock) {
            when {
                inFlight.containsKey(requestId) -> duplicateInFlight = true
                preCanceled.remove(requestId) -> {
                    recordTerminalLocked(requestId)
                    canceledBeforeStart = true
                }
                else -> inFlight[requestId] = entry
            }
        }

        if (duplicateInFlight) {
            job.cancel()
            reply.error("BAD_INPUT", "requestId is already in flight", mapOf("requestId" to requestId))
            return
        }
        if (canceledBeforeStart) {
            job.cancel()
            reply.error(
                "CANCELED",
                "Journey request was canceled",
                mapOf("requestId" to requestId),
            )
            return
        }

        job.invokeOnCompletion {
            synchronized(requestLock) {
                if (inFlight[requestId] === entry) {
                    inFlight.remove(requestId)
                }
                recordTerminalLocked(requestId)
            }
        }
        logInfo("planJourney start reqHash=${reqHash(requestId)} timeoutMs=$timeoutMs")
        job.start()
    }

    private suspend fun executePlanJourney(
        requestId: String,
        meetingId: String,
        originLat: Double,
        originLon: Double,
        destLat: Double,
        destLon: Double,
        maxWalkMeters: Int,
        departAtUtcMs: Long,
        arriveBeforeUtcMs: Long?,
        timeoutMs: Long,
        entry: InFlightRequest,
        reply: BridgeResult,
    ) {
        val startedAtMs = System.nanoTime() / 1_000_000L
        fun elapsedMs(): Long = (System.nanoTime() / 1_000_000L) - startedAtMs
        val reqTag = reqHash(requestId)
        try {
            withTimeout(timeoutMs) {
                coroutineContext.ensureActive()
                val engine = ensureEngine(feedId)
                val network = routingNetwork
                if (engine == null || network == null) {
                    logInfo("planJourney missing_feed reqHash=$reqTag elapsedMs=${elapsedMs()}")
                    sendError(
                        reply,
                        "MISSING_FEED",
                        "Atlas static network is not ready: ${initFailure ?: "unknown"}",
                        mapOf("requestId" to requestId, "meetingId" to meetingId, "isSynthetic" to false),
                    )
                    return@withTimeout
                }

                val metadata = network.metadata
                val now = clock()
                val departAt = Instant.fromEpochMilliseconds(departAtUtcMs)
                val arriveBy = arriveBeforeUtcMs?.let { Instant.fromEpochMilliseconds(it) }
                val effectiveDepartAt = if (arriveBy != null) {
                    val windowStart = arriveBy - 90.minutes
                    if (departAt < windowStart) windowStart else departAt
                } else {
                    departAt
                }

                if (isFeedExpired(metadata, now) || isFeedExpired(metadata, effectiveDepartAt)) {
                    logInfo("planJourney feed_expired reqHash=$reqTag elapsedMs=${elapsedMs()}")
                    sendError(
                        reply,
                        "FEED_EXPIRED",
                        "The Metro Transit schedule expired on ${metadata.validTo}. " +
                            "Refresh the static schedule in Settings or use external directions.",
                        mapOf(
                            "requestId" to requestId,
                            "meetingId" to meetingId,
                            "isSynthetic" to false,
                            "feedId" to feedId.value,
                            "validTo" to metadata.validTo?.toString(),
                        ),
                    )
                    return@withTimeout
                }

                fun buildPlanRequest(transfers: Int) = TripPlanRequest(
                    origin = GeoPoint(originLat, originLon),
                    destination = GeoPoint(destLat, destLon),
                    departAt = effectiveDepartAt,
                    arriveBy = arriveBy,
                    maxTransfers = transfers,
                    maxWalkMeters = maxWalkMeters.toDouble(),
                )

                coroutineContext.ensureActive()
                val primaryOutcome = engine.planJourney(buildPlanRequest(1))
                coroutineContext.ensureActive()

                val primaryMissing = (primaryOutcome as? JourneyOutcome.Unavailable)?.missing.orEmpty()
                val noStopsWithinWalkLimit = primaryMissing.any { it in NO_STOP_COVERAGE_REASONS }
                val shouldRetryWithSecondTransfer = !noStopsWithinWalkLimit && (
                    primaryOutcome is JourneyOutcome.Unavailable ||
                        (primaryOutcome is JourneyOutcome.Planned && primaryOutcome.journeys.isEmpty())
                    )

                val outcome = if (shouldRetryWithSecondTransfer) {
                    coroutineContext.ensureActive()
                    logInfo("planJourney pass2 reqHash=$reqTag elapsedMs=${elapsedMs()}")
                    engine.planJourney(buildPlanRequest(2))
                } else {
                    primaryOutcome
                }

                coroutineContext.ensureActive()
                when (outcome) {
                    is JourneyOutcome.Planned -> {
                        if (outcome.journeys.isEmpty()) {
                            logInfo("planJourney no_itinerary_empty reqHash=$reqTag elapsedMs=${elapsedMs()}")
                            sendError(
                                reply,
                                "NO_ITINERARY",
                                "No transit route found between locations for the requested departure time",
                                mapOf(
                                    "requestId" to requestId,
                                    "meetingId" to meetingId,
                                    "missingReasons" to emptyList<String>(),
                                ),
                            )
                            return@withTimeout
                        }

                        val options = outcome.journeys.map { journey ->
                            serializeJourney(journey, network)
                        }
                        logInfo("planJourney planned reqHash=$reqTag options=${options.size} elapsedMs=${elapsedMs()}")
                        sendSuccess(
                            reply,
                            mapOf(
                                "version" to AtlasChannelAdapter.CURRENT_API_VERSION,
                                "requestId" to requestId,
                                "meetingId" to meetingId,
                                "providerId" to ROUTING_PROVIDER_ID,
                                "dataSource" to "static_gtfs",
                                "isSynthetic" to false,
                                "fetchedAtUtcMs" to metadata.fetchedAt.toEpochMilliseconds(),
                                "freshness" to freshness(metadata, clock()),
                                "options" to options,
                            ),
                        )
                    }

                    is JourneyOutcome.Unavailable -> {
                        if ("timeout" in outcome.missing) {
                            logInfo("planJourney planner_timeout reqHash=$reqTag elapsedMs=${elapsedMs()}")
                            sendError(
                                reply,
                                "TIMEOUT",
                                "Transit schedule is still initializing or route calculation timed out",
                                mapOf(
                                    "requestId" to requestId,
                                    "meetingId" to meetingId,
                                    "timeoutMs" to timeoutMs,
                                ),
                            )
                        } else {
                            logInfo("planJourney no_itinerary reqHash=$reqTag reasons=${outcome.missing} elapsedMs=${elapsedMs()}")
                            sendError(
                                reply,
                                "NO_ITINERARY",
                                outcome.reason,
                                mapOf(
                                    "requestId" to requestId,
                                    "meetingId" to meetingId,
                                    "missingReasons" to outcome.missing,
                                ),
                            )
                        }
                    }
                }
            }
        } catch (e: TimeoutCancellationException) {
            logInfo(
                "planJourney timeout_exception reqHash=$reqTag " +
                    "canceledByCaller=${entry.canceledByCaller.get()} elapsedMs=${elapsedMs()}",
            )
            if (entry.canceledByCaller.get()) {
                sendCancelled(reply, requestId)
                throw CancellationException("Journey request $requestId canceled during timeout", e)
            } else {
                sendError(
                    reply,
                    "TIMEOUT",
                    "Transit schedule is still initializing or route calculation timed out",
                    mapOf(
                        "requestId" to requestId,
                        "meetingId" to meetingId,
                        "timeoutMs" to timeoutMs,
                    ),
                )
            }
        } catch (e: CancellationException) {
            logInfo(
                "planJourney coroutine_canceled reqHash=$reqTag " +
                    "canceledByCaller=${entry.canceledByCaller.get()} elapsedMs=${elapsedMs()}",
            )
            sendCancelled(reply, requestId)
            throw e
        } catch (e: Exception) {
            logInfo("planJourney error reqHash=$reqTag type=${e::class.java.simpleName} elapsedMs=${elapsedMs()}")
            sendError(
                reply,
                "NATIVE_FAILURE",
                "Journey planning failed: ${e.message}",
                mapOf("requestId" to requestId, "meetingId" to meetingId),
            )
        }
    }

    private fun handleCancelRequest(arguments: Map<*, *>?, reply: BridgeResult) {
        val requestId = arguments.stringArg("requestId")?.trim().orEmpty()
        if (requestId.isEmpty()) {
            reply.success(mapOf("cancelRequested" to false, "requestId" to requestId))
            return
        }

        val activeEntry: InFlightRequest?
        synchronized(requestLock) {
            activeEntry = inFlight.remove(requestId)
            if (activeEntry != null) {
                activeEntry.canceledByCaller.set(true)
                recordTerminalLocked(requestId)
            } else if (!terminalRequests.contains(requestId)) {
                markPreCanceledLocked(requestId)
            }
        }

        logInfo("cancelRequest reqHash=${reqHash(requestId)} active=${activeEntry != null}")
        if (activeEntry != null) {
            activeEntry.job.cancel()
            reply.success(mapOf("cancelRequested" to true, "requestId" to requestId))
        } else {
            // Never report an active cancellation when no job was running yet or after completion.
            reply.success(mapOf("cancelRequested" to false, "requestId" to requestId))
        }
    }

    private fun handleRefreshStaticFeed(arguments: Map<*, *>?, reply: BridgeResult) {
        val userConsented = arguments.boolArg("userConsented") == true
        if (!userConsented) {
            reply.error(
                "PERMISSION_REQUIRED",
                "User consent (transitFeedRefresh) is required before refreshing the transit schedule.",
                null,
            )
            return
        }

        val requested = arguments.stringArg("feedId")?.takeIf { it.isNotBlank() } ?: DEFAULT_FEED_ID
        val target = if (requested == "default") feedId else FeedId(requested)
        if (target != feedId) {
            reply.error("BAD_INPUT", "Unsupported feedId: $requested", null)
            return
        }

        scope.launch(ioDispatcher) {
            try {
                val acquirer = GtfsFeedAcquirer(
                    userAgent = USER_AGENT,
                    transport = httpTransportFactory?.invoke() ?: com.intellitrip.gtfs.defaultHttpTransport(),
                )
                val refresher = StaticFeedRefresher(
                    feedId = target,
                    sourceUrl = feedSourceUrl,
                    acquirer = acquirer,
                    store = snapshotStore,
                    clock = clock,
                    ioDispatcher = ioDispatcher,
                )
                when (val outcome = refresher.refresh()) {
                    is RefreshOutcome.Activated -> {
                        val network = initMutex.withLock {
                            val rebuilt = buildNetwork(outcome.feed)
                            // Warm the lazy StopTimeIndex before releasing the lock so first planJourney avoids cold index load.
                            val warmStartMs = System.nanoTime() / 1_000_000L
                            rebuilt.stops.firstOrNull()?.let { rebuilt.tripsServing(it.key) }
                            logInfo("StopTimeIndex refreshed stops=${rebuilt.stops.size} elapsedMs=${(System.nanoTime() / 1_000_000L) - warmStartMs}")
                            installNetworkAndEngineLocked(target, outcome.feed, rebuilt)
                            rebuilt
                        }
                        sendSuccess(reply, statusMapForNetwork(network, sourceOverride = "remote_gtfs_refreshed"))
                    }

                    is RefreshOutcome.NotModified -> {
                        val engine = ensureEngine(target)
                        val network = routingNetwork
                        if (engine == null || network == null) {
                            sendError(
                                reply,
                                "MISSING_FEED",
                                "Snapshot is not available after 304 Not Modified.",
                                null,
                            )
                        } else {
                            sendSuccess(reply, statusMapForNetwork(network, sourceOverride = "not_modified"))
                        }
                    }

                    is RefreshOutcome.Rejected -> {
                        sendError(
                            reply,
                            "NETWORK_FAILURE",
                            "Transit schedule refresh failed: ${outcome.reason}",
                            null,
                        )
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                sendError(
                    reply,
                    "NETWORK_FAILURE",
                    "Transit schedule refresh failed: ${e.message}",
                    null,
                )
            }
        }
    }

    private fun handleOfflineStatus(arguments: Map<*, *>?, reply: BridgeResult) {
        val requested = arguments.stringArg("feedId")?.takeIf { it.isNotBlank() } ?: "default"
        if (requested != "default" && requested != DEFAULT_FEED_ID) {
            reply.success(
                mapOf(
                    "staticNetwork" to "unavailable",
                    "basemap" to "cached_tiles",
                    "routing" to "unavailable",
                    "dataAgeSeconds" to null,
                    "notes" to "Only the bundled $DEFAULT_FEED_ID feed is supported.",
                ),
            )
            return
        }

        scope.launch(ioDispatcher) {
            try {
                val now = clock()
                val snapshot = snapshotStore.activeSnapshot(feedId)
                val metadata = snapshot?.metadata ?: routingNetwork?.metadata
                val ready = atlasEngine != null && routingNetwork != null
                val expired = metadata != null && isFeedExpired(metadata, now)
                val dataAgeSeconds = metadata?.let { meta ->
                    ((now - meta.fetchedAt).inWholeSeconds).coerceAtLeast(0L).toInt()
                }
                val staticState = when {
                    expired -> "expired"
                    ready -> "ready"
                    else -> "unavailable"
                }
                val routingState = if (ready && !expired) "ready" else "unavailable"
                val note = when {
                    expired -> "Metro Transit schedule expired on ${metadata.validTo}; " +
                        "planning is disabled until refreshed in Settings."
                    ready -> "Metro Transit schedule loaded (valid through ${metadata?.validTo ?: "unknown"}); no live vehicle data."
                    else -> "Bundled schedule is not initialized: ${initFailure ?: "unknown"}."
                }
                sendSuccess(
                    reply,
                    mapOf(
                        "staticNetwork" to staticState,
                        "basemap" to "cached_tiles",
                        "routing" to routingState,
                        "dataAgeSeconds" to dataAgeSeconds,
                        "notes" to note,
                    ),
                )
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                sendError(reply, "NATIVE_FAILURE", "Failed to read offline status: ${e.message}", null)
            }
        }
    }

    internal fun installEngineForTesting(engine: AtlasEngine, network: RoutingNetwork) {
        routingNetwork = network
        atlasEngine = engine
        initFailure = null
    }

    private fun installNetworkAndEngineLocked(
        target: FeedId,
        feed: StaticFeed,
        network: RoutingNetwork,
    ): AtlasEngine {
        val planner = StaticNetworkPlanner(
            network = network,
            agencyZone = AGENCY_ZONE,
            providerId = ROUTING_PROVIDER_ID,
        )
        val engine = AtlasEngine(
            feedId = target,
            providers = AtlasProviders(
                routing = planner,
                transitStatic = InMemoryStaticTransitProvider(feed, providerId = "atlas_gtfs_static"),
            ),
            offlineAvailable = !isFeedExpired(network.metadata, clock()),
        )
        routingNetwork = network
        atlasEngine = engine
        initFailure = null
        return engine
    }

    private suspend fun ensureEngine(target: FeedId): AtlasEngine? = initMutex.withLock {
        if (target != feedId) {
            initFailure = "unsupported_feed"
            return@withLock null
        }
        atlasEngine?.let { return@withLock it }

        val active = snapshotStore.activeSnapshot(target)
        val needsSeed = active == null || active.metadata.fetchedAt < BUNDLED_FEED_CAPTURED_AT
        val feed = try {
            if (needsSeed) {
                seedFromBundledAsset(target)
            } else {
                offlineRegistry.loadStaticFeed(target)
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            initFailure = "parse_failure"
            null
        }
        if (feed == null) {
            initFailure = initFailure ?: "parse_failure"
            return@withLock null
        }

        val network = try {
            buildNetwork(feed)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            initFailure = "network_failed"
            null
        }
        if (network == null) return@withLock null

        // Warm the lazy StopTimeIndex before exposing the engine so the first planJourney call does not pay cold index parse.
        val warmStartMs = System.nanoTime() / 1_000_000L
        network.stops.firstOrNull()?.let { network.tripsServing(it.key) }
        logInfo("StopTimeIndex ensured stops=${network.stops.size} elapsedMs=${(System.nanoTime() / 1_000_000L) - warmStartMs}")
        installNetworkAndEngineLocked(target, feed, network)
    }

    /**
     * Seeds the snapshot from the asset only. `StaticFeedRefresher` is used for
     * its validated staging + stop-time index, with an in-memory transport:
     * no request leaves the device.
     */
    private fun seedFromBundledAsset(target: FeedId) = try {
        val payload = bundledAssetOpener?.invoke()
            ?: requireNotNull(context).assets.open(ASSET_PATH).use { it.readBytes() }
        val etag = "asset-" + GtfsFeedAcquirer.sha256(payload).take(16)
        val transport = GtfsFeedAcquirer.HttpTransport { _ ->
            GtfsFeedAcquirer.HttpResponse(200, payload, mapOf("ETag" to etag))
        }
        val refresher = StaticFeedRefresher(
            feedId = target,
            sourceUrl = ASSET_SOURCE_URL,
            acquirer = GtfsFeedAcquirer(
                userAgent = USER_AGENT,
                transport = transport,
            ),
            store = snapshotStore,
            clock = { BUNDLED_FEED_CAPTURED_AT },
        )
        when (val outcome = refresher.refreshBlocking()) {
            is RefreshOutcome.Activated -> outcome.feed
            is RefreshOutcome.NotModified -> offlineRegistry.loadStaticFeed(target)
            is RefreshOutcome.Rejected -> {
                initFailure = "asset_rejected"
                null
            }
        }
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        initFailure = "asset_seed_failed"
        null
    }

    private fun buildNetwork(feed: StaticFeed): RoutingNetwork {
        val reader = snapshotStore.stopTimeReader(feed.feedId)
        val source = reader?.let { index ->
            object : StopTimeSource {
                override fun stopTimesFor(trip: TripKey) =
                    index.stopTimesFor(trip) { stopId -> StopKey(feed.feedId, stopId) }

                override fun tripsServing(stop: StopKey) = index.tripsServing(stop)
            }
        }
        return RoutingNetwork(
            feedId = feed.feedId,
            metadata = feed.metadata,
            routes = feed.routes,
            stops = feed.stops,
            trips = feed.trips,
            stopTimes = feed.stopTimes,
            stopTimeSource = source,
            transfers = feed.transfers,
            calendars = feed.calendars,
            calendarDates = feed.calendarDates,
            agencies = feed.agencies,
            frequencies = feed.frequencies,
        )
    }

    private fun serializeJourney(journey: JourneyOption, network: RoutingNetwork): Map<String, Any?> {
        val rawLegs = journey.legs
        val legs = rawLegs.mapIndexed { index, leg ->
            when (leg) {
                is Leg.WalkLeg -> {
                    val previous = if (index > 0) rawLegs[index - 1] else null
                    val next = if (index < rawLegs.size - 1) rawLegs[index + 1] else null
                    val fromLabel = when {
                        previous is Leg.Transit -> network.stopsByKey[previous.toStopKey]?.name
                            ?: previous.toStopKey.stopId
                        index == 0 -> "Starting Point"
                        else -> nearestStopName(network, leg.from) ?: "Origin"
                    }
                    val toLabel = when {
                        next is Leg.Transit -> network.stopsByKey[next.fromStopKey]?.name
                            ?: next.fromStopKey.stopId
                        index == rawLegs.size - 1 -> "Meeting Destination"
                        else -> nearestStopName(network, leg.to) ?: "Destination"
                    }
                    val resolvedToLabel = if (fromLabel == toLabel) {
                        if (index == rawLegs.size - 1) "Meeting Destination" else "$toLabel (Transfer)"
                    } else {
                        toLabel
                    }
                    mapOf(
                        "mode" to "walk",
                        "fromLabel" to fromLabel,
                        "toLabel" to resolvedToLabel,
                        "startUtcMs" to leg.start.toEpochMilliseconds(),
                        "endUtcMs" to leg.end.toEpochMilliseconds(),
                        "routeLabel" to null,
                        "distanceMeters" to leg.meters.toInt(),
                        "fromLat" to leg.from.lat,
                        "fromLon" to leg.from.lon,
                        "toLat" to leg.to.lat,
                        "toLon" to leg.to.lon,
                    )
                }

                is Leg.Transit -> {
                    val route = network.routesByKey[leg.routeKey]
                    val fromStop = network.stopsByKey[leg.fromStopKey]
                    val toStop = network.stopsByKey[leg.toStopKey]
                    val mode = when (route?.routeType) {
                        0, 1, 2 -> "rail"
                        3, 11 -> "bus"
                        else -> "other_transit"
                    }
                    mapOf(
                        "mode" to mode,
                        "fromLabel" to (fromStop?.name ?: leg.fromStopKey.stopId),
                        "toLabel" to (toStop?.name ?: leg.toStopKey.stopId),
                        "startUtcMs" to leg.departure.toEpochMilliseconds(),
                        "endUtcMs" to leg.arrival.toEpochMilliseconds(),
                        "routeLabel" to (route?.shortName ?: route?.longName ?: leg.routeKey.routeId),
                        "distanceMeters" to null,
                        "fromLat" to fromStop?.location?.lat,
                        "fromLon" to fromStop?.location?.lon,
                        "toLat" to toStop?.location?.lat,
                        "toLon" to toStop?.location?.lon,
                    )
                }

                is Leg.Other -> mapOf(
                    "mode" to "other_transit",
                    "fromLabel" to leg.label,
                    "toLabel" to leg.label,
                    "startUtcMs" to leg.start.toEpochMilliseconds(),
                    "endUtcMs" to leg.end.toEpochMilliseconds(),
                    "routeLabel" to leg.label,
                    "distanceMeters" to null,
                    "fromLat" to leg.from.lat,
                    "fromLon" to leg.from.lon,
                    "toLat" to leg.to.lat,
                    "toLon" to leg.to.lon,
                )
            }
        }

        val walkMeters = journey.legs.filterIsInstance<Leg.WalkLeg>().sumOf { it.meters }.toInt()
        val transitLegCount = journey.legs.count { it is Leg.Transit }
        val transferCount = if (transitLegCount > 0) transitLegCount - 1 else 0
        val transferConfidence = when {
            transitLegCount == 0 -> "direct_walk"
            transferCount == 0 -> "high"
            journey.transfers.any { it.confidence == TransferConfidence.LOW } -> "low"
            journey.transfers.any { it.confidence == TransferConfidence.MEDIUM } -> "medium"
            journey.transfers.any {
                it.confidence == TransferConfidence.SCHEDULED_UNKNOWN ||
                    it.confidence == TransferConfidence.UNKNOWN
            } -> "scheduled_unknown"
            else -> "high"
        }

        return mapOf(
            "journeyId" to journey.id,
            "departUtcMs" to journey.departure.toEpochMilliseconds(),
            "arriveUtcMs" to journey.arrival.toEpochMilliseconds(),
            "walkMeters" to walkMeters,
            "transferCount" to transferCount,
            "transferConfidence" to transferConfidence,
            "legs" to legs,
        )
    }

    private fun nearestStopName(network: RoutingNetwork, point: GeoPoint): String? =
        network.stops.minByOrNull {
            val dLat = it.location.lat - point.lat
            val dLon = it.location.lon - point.lon
            dLat * dLat + dLon * dLon
        }?.name

    private fun missingStatus(source: String): Map<String, Any?> = mapOf(
        "state" to "missing",
        "feedHash" to null,
        "fetchedAt" to null,
        "expiresAt" to null,
        "stopCount" to 0,
        "source" to source,
    )

    private fun failureSource(fromCacheOnly: Boolean): String {
        val failure = initFailure ?: "cache_miss"
        val assetFailure = failure == "bundled_asset_missing" ||
            failure == "asset_rejected" ||
            failure == "asset_seed_failed"
        // `fromCacheOnly=false` is a request for a refresh, but this build has
        // no consented network feed path. Say so rather than silently fetching.
        return if (!fromCacheOnly && assetFailure) "remote_disabled" else failure
    }

    private fun isFeedExpired(metadata: FeedMetadata, now: Instant): Boolean {
        val validTo = metadata.validTo ?: return false
        return now.toLocalDateTime(AGENCY_ZONE).date > validTo
    }

    private fun freshness(metadata: FeedMetadata, now: Instant): String {
        val today = now.toLocalDateTime(AGENCY_ZONE).date
        val validTo = metadata.validTo
        if (validTo != null && today > validTo) return "expired"
        val validFrom = metadata.validFrom
        if (validFrom != null && today < validFrom) return "unknown"
        if (now - metadata.fetchedAt > 7.days) return "stale"
        return "fresh"
    }

    private fun expiresAtUtcMs(metadata: FeedMetadata): Long? {
        val validTo = metadata.validTo ?: return null
        return LocalDateTime(validTo, LocalTime(23, 59, 59))
            .toInstant(AGENCY_ZONE)
            .toEpochMilliseconds()
    }

    private fun isValidCoordinate(lat: Double, lon: Double): Boolean =
        lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0

    private suspend fun sendSuccess(result: BridgeResult, value: Any?) {
        withContext(NonCancellable + mainDispatcher) { result.success(value) }
    }

    private suspend fun sendError(
        result: BridgeResult,
        code: String,
        message: String,
        details: Any?,
    ) {
        withContext(NonCancellable + mainDispatcher) { result.error(code, message, details) }
    }

    /**
     * A cancelled planJourney must still complete its Dart Future once; otherwise
     * a cancellable UI leaves a pending request forever. NonCancellable is
     * required because this coroutine is already cancelled here.
     */
    private suspend fun sendCancelled(result: BridgeResult, requestId: String) {
        withContext(NonCancellable + mainDispatcher) {
            result.error(
                "CANCELED",
                "Journey request was canceled",
                mapOf("requestId" to requestId),
            )
        }
    }
}
