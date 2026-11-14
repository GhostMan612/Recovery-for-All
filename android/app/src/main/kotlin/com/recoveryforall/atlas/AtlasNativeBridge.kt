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
import java.util.concurrent.ConcurrentHashMap
import kotlin.time.Duration.Companion.days
import kotlin.time.Duration.Companion.minutes
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlinx.datetime.toLocalDateTime

/**
 * API-26+ implementation of `recoveryforall/atlas_v1`.
 *
 * The bundled static GTFS snapshot is the only data source. No remote routing,
 * no live positions and no network acquisition happen here; those need a
 * separate, explicit consent path.
 */
internal class AtlasNativeBridge(
    private val context: Context,
) : AtlasChannelAdapter.Delegate {

    private companion object {
        const val DEFAULT_FEED_ID = "metro-transit-regional"
        const val ASSET_PATH = "gtfs/metro_transit_regional.zip"
        const val ASSET_SOURCE_URL = "asset://gtfs/metro_transit_regional.zip"
        const val ROUTING_PROVIDER_ID = "atlas_static_planner"

        /**
         * Capture time of the bundled snapshot, not the time the app launched.
         *
         * The asset's calendars cover 2026-10-10 through 2026-11-27; this is
         * the date the snapshot was taken. Update it with the asset and its
         * PROVENANCE.txt in the same commit.
         */
        val BUNDLED_FEED_CAPTURED_AT: Instant = Instant.parse("2026-11-13T00:00:00Z")

        val AGENCY_ZONE: TimeZone = TimeZone.of("America/Chicago")
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val initMutex = Mutex()
    private val inFlight = ConcurrentHashMap<String, Job>()

    @Volatile
    private var atlasEngine: AtlasEngine? = null

    @Volatile
    private var routingNetwork: RoutingNetwork? = null

    @Volatile
    private var initFailure: String? = null

    private val feedId = FeedId(DEFAULT_FEED_ID)

    private val snapshotStore: StaticFeedSnapshotStore by lazy {
        StaticFeedSnapshotStore(PlatformFileStore(context.filesDir.absolutePath))
    }

    private val offlineRegistry: OfflineRegistry by lazy {
        OfflineRegistry(JvmOfflineSnapshotPort(snapshotStore))
    }

    /** Warms the local snapshot without blocking the Flutter platform thread. */
    fun initAsync() {
        scope.launch(Dispatchers.IO) {
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
        when (call.method) {
            "getCapabilities" -> result.success(capabilities())
            "loadStaticNetwork" -> handleLoadStaticNetwork(call, result)
            "planJourney" -> handlePlanJourney(call, result)
            "cancelRequest" -> handleCancelRequest(call, result)
            "getOfflineStatus" -> handleOfflineStatus(call, result)
            "getWeather" -> result.success(mapOf("status" to "unsupported"))
            else -> result.notImplemented()
        }
    }

    private fun capabilities(): Map<String, Any?> {
        val engine = atlasEngine
        val network = routingNetwork
        val usable = engine != null &&
            network != null &&
            !isFeedExpired(network.metadata, Clock.System.now())
        val hasRouting = usable && engine?.providers?.routing != null
        val hasStatic = usable && engine?.providers?.transitStatic != null
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

    private fun handleLoadStaticNetwork(call: MethodCall, result: MethodChannel.Result) {
        val requested = call.argument<String>("feedId")?.takeIf { it.isNotBlank() } ?: DEFAULT_FEED_ID
        val target = if (requested == "default") feedId else FeedId(requested)
        val fromCacheOnly = call.argument<Boolean>("fromCacheOnly") ?: true

        if (target != feedId) {
            result.success(missingStatus("unsupported_feed"))
            return
        }

        scope.launch(Dispatchers.IO) {
            try {
                val engine = ensureEngine(target)
                val network = routingNetwork
                if (engine == null || network == null) {
                    sendSuccess(result, missingStatus(failureSource(fromCacheOnly)))
                    return@launch
                }

                val metadata = network.metadata
                val expired = isFeedExpired(metadata, Clock.System.now())
                val source = if (metadata.sourceUrl?.startsWith("asset:") == true) {
                    "bundled_asset"
                } else {
                    "static_gtfs"
                }
                sendSuccess(
                    result,
                    mapOf(
                        "state" to if (expired) "expired" else "ready",
                        "feedHash" to metadata.hash,
                        "fetchedAt" to metadata.fetchedAt.toEpochMilliseconds(),
                        "expiresAt" to expiresAtUtcMs(metadata),
                        "stopCount" to network.stops.size,
                        "source" to source,
                    ),
                )
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                sendError(result, "NATIVE_FAILURE", "Failed to load static network: ${e.message}", null)
            }
        }
    }

    private fun handlePlanJourney(call: MethodCall, result: MethodChannel.Result) {
        val requestId = call.argument<String>("requestId")?.trim().orEmpty()
        if (requestId.isEmpty()) {
            result.error("BAD_INPUT", "requestId must not be empty", null)
            return
        }
        if (inFlight.containsKey(requestId)) {
            result.error("BAD_INPUT", "requestId is already in flight", mapOf("requestId" to requestId))
            return
        }

        val allowRemote = call.argument<Boolean>("allowRemote") ?: false
        if (allowRemote) {
            result.error(
                "REMOTE_DISABLED",
                "Remote routing is disabled in this build; only the bundled static planner is available.",
                mapOf("requestId" to requestId),
            )
            return
        }

        val modes = call.argument<List<*>>("transitModes")
            ?.mapNotNull { it as? String }
            ?.toSet()
        if (modes != null && (modes.isEmpty() || modes.any { it !in setOf("bus", "rail") })) {
            result.error(
                "BAD_INPUT",
                "transitModes must contain 'bus' and/or 'rail'",
                mapOf("requestId" to requestId),
            )
            return
        }

        val meetingId = call.argument<String>("meetingId") ?: ""
        val originMap = call.argument<Map<String, Any?>>("origin")
        val destinationMap = call.argument<Map<String, Any?>>("destination")
        val originLat = (originMap?.get("lat") as? Number)?.toDouble()
        val originLon = (originMap?.get("lon") as? Number)?.toDouble()
        val destLat = (destinationMap?.get("lat") as? Number)?.toDouble()
        val destLon = (destinationMap?.get("lon") as? Number)?.toDouble()

        if (originLat == null || originLon == null || destLat == null || destLon == null) {
            result.error("BAD_INPUT", "Missing origin or destination coordinates", null)
            return
        }
        if (!isValidCoordinate(originLat, originLon) || !isValidCoordinate(destLat, destLon)) {
            result.error(
                "BAD_INPUT",
                "Coordinates out of bounds: origin($originLat, $originLon), dest($destLat, $destLon)",
                null,
            )
            return
        }

        val maxWalkMeters = (call.argument<Number>("maxWalkMeters"))?.toInt() ?: 1500
        if (maxWalkMeters < 0) {
            result.error("BAD_INPUT", "maxWalkMeters must not be negative", null)
            return
        }

        val departAtUtcMs = (call.argument<Number>("departAtUtcMs"))?.toLong() ?: System.currentTimeMillis()
        val arriveBeforeUtcMs = (call.argument<Number>("arriveBeforeUtcMs"))?.toLong()

        val job = scope.launch(Dispatchers.Default) {
            try {
                val engine = ensureEngine(feedId)
                val network = routingNetwork
                if (engine == null || network == null) {
                    sendError(
                        result,
                        "MISSING_FEED",
                        "Atlas static network is not ready: ${initFailure ?: "unknown"}",
                        mapOf("meetingId" to meetingId, "isSynthetic" to false),
                    )
                    return@launch
                }

                val metadata = network.metadata
                val departAt = Instant.fromEpochMilliseconds(departAtUtcMs)
                val arriveBy = arriveBeforeUtcMs?.let { Instant.fromEpochMilliseconds(it) }
                val effectiveDepartAt = if (arriveBy != null) {
                    val windowStart = arriveBy - 90.minutes
                    if (departAt < windowStart) windowStart else departAt
                } else {
                    departAt
                }

                if (isFeedExpired(metadata, Clock.System.now()) || isFeedExpired(metadata, effectiveDepartAt)) {
                    sendError(
                        result,
                        "FEED_EXPIRED",
                        "The bundled Metro Transit schedule expired on ${metadata.validTo}. " +
                            "Journey planning is disabled until a newer feed is bundled.",
                        mapOf(
                            "meetingId" to meetingId,
                            "isSynthetic" to false,
                            "feedId" to feedId.value,
                            "validTo" to metadata.validTo?.toString(),
                        ),
                    )
                    return@launch
                }

                fun buildPlanRequest(transfers: Int) = TripPlanRequest(
                    origin = GeoPoint(originLat, originLon),
                    destination = GeoPoint(destLat, destLon),
                    departAt = effectiveDepartAt,
                    arriveBy = arriveBy,
                    maxTransfers = transfers,
                    maxWalkMeters = maxWalkMeters.toDouble(),
                )

                val primaryOutcome = engine.planJourney(buildPlanRequest(1))
                val outcome = if (primaryOutcome is JourneyOutcome.Unavailable ||
                    (primaryOutcome is JourneyOutcome.Planned && primaryOutcome.journeys.isEmpty())
                ) {
                    engine.planJourney(buildPlanRequest(2))
                } else {
                    primaryOutcome
                }

                when (outcome) {
                    is JourneyOutcome.Planned -> {
                        if (outcome.journeys.isEmpty()) {
                            sendError(
                                result,
                                "NO_ITINERARY",
                                "No transit route found between locations for the requested departure time",
                                mapOf("requestId" to requestId, "meetingId" to meetingId),
                            )
                            return@launch
                        }

                        val options = outcome.journeys.map { journey ->
                            serializeJourney(journey, network)
                        }
                        sendSuccess(
                            result,
                            mapOf(
                                "version" to AtlasChannelAdapter.CURRENT_API_VERSION,
                                "requestId" to requestId,
                                "meetingId" to meetingId,
                                "providerId" to ROUTING_PROVIDER_ID,
                                "dataSource" to "static_gtfs",
                                "isSynthetic" to false,
                                "fetchedAtUtcMs" to metadata.fetchedAt.toEpochMilliseconds(),
                                "freshness" to freshness(metadata, Clock.System.now()),
                                "options" to options,
                            ),
                        )
                    }

                    is JourneyOutcome.Unavailable -> sendError(
                        result,
                        "NO_ITINERARY",
                        outcome.reason,
                        mapOf("requestId" to requestId, "meetingId" to meetingId),
                    )
                }
            } catch (e: CancellationException) {
                sendCancelled(result, requestId)
                throw e
            } catch (e: Exception) {
                sendError(
                    result,
                    "NATIVE_FAILURE",
                    "Journey planning failed: ${e.message}",
                    mapOf("requestId" to requestId, "meetingId" to meetingId),
                )
            }
        }

        inFlight[requestId] = job
        job.invokeOnCompletion { inFlight.remove(requestId, job) }
    }

    private fun handleCancelRequest(call: MethodCall, result: MethodChannel.Result) {
        val requestId = call.argument<String>("requestId") ?: ""
        val job = inFlight.remove(requestId)
        if (job != null) {
            job.cancel()
            result.success(mapOf("cancelRequested" to true, "requestId" to requestId))
        } else {
            // Never report a cancellation that did not happen.
            result.success(mapOf("cancelRequested" to false, "requestId" to requestId))
        }
    }

    private fun handleOfflineStatus(call: MethodCall, result: MethodChannel.Result) {
        val requested = call.argument<String>("feedId")?.takeIf { it.isNotBlank() } ?: "default"
        if (requested != "default" && requested != DEFAULT_FEED_ID) {
            result.success(
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

        scope.launch(Dispatchers.IO) {
            try {
                val now = Clock.System.now()
                val snapshot = snapshotStore.activeSnapshot(feedId)
                val metadata = snapshot?.metadata
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
                    expired -> "Bundled schedule expired on ${metadata?.validTo}; " +
                        "planning is disabled until a newer feed is bundled."
                    ready -> "Bundled Metro Transit schedule loaded; no live vehicle data."
                    else -> "Bundled schedule is not initialized: ${initFailure ?: "unknown"}."
                }
                sendSuccess(
                    result,
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
                sendError(result, "NATIVE_FAILURE", "Failed to read offline status: ${e.message}", null)
            }
        }
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
            offlineAvailable = !isFeedExpired(network.metadata, Clock.System.now()),
        )

        routingNetwork = network
        atlasEngine = engine
        initFailure = null
        engine
    }

    /**
     * Seeds the snapshot from the asset only. `StaticFeedRefresher` is used for
     * its validated staging + stop-time index, with an in-memory transport:
     * no request leaves the device.
     */
    private fun seedFromBundledAsset(target: FeedId) = try {
        val payload = context.assets.open(ASSET_PATH).use { it.readBytes() }
        val etag = "asset-" + GtfsFeedAcquirer.sha256(payload).take(16)
        val transport = GtfsFeedAcquirer.HttpTransport { _ ->
            GtfsFeedAcquirer.HttpResponse(200, payload, mapOf("ETag" to etag))
        }
        val refresher = StaticFeedRefresher(
            feedId = target,
            sourceUrl = ASSET_SOURCE_URL,
            acquirer = GtfsFeedAcquirer(
                userAgent = "RecoveryForAll/1.0 (Android; Atlas-Bridge)",
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

    private suspend fun sendSuccess(result: MethodChannel.Result, value: Any?) {
        withContext(Dispatchers.Main) { result.success(value) }
    }

    private suspend fun sendError(
        result: MethodChannel.Result,
        code: String,
        message: String,
        details: Any?,
    ) {
        withContext(Dispatchers.Main) { result.error(code, message, details) }
    }

    /**
     * A cancelled planJourney must still complete its Dart Future; otherwise a
     * cancellable UI leaves a pending request forever. NonCancellable is
     * required because this coroutine is already cancelled here.
     */
    private suspend fun sendCancelled(result: MethodChannel.Result, requestId: String) {
        withContext(NonCancellable + Dispatchers.Main) {
            result.error(
                "CANCELED",
                "Journey request was canceled",
                mapOf("requestId" to requestId),
            )
        }
    }
}
