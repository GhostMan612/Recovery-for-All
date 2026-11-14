// android/app/src/test/kotlin/com/recoveryforall/atlas/AtlasNativeBridgeTest.kt
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

package com.recoveryforall.atlas

import com.intellitrip.contracts.FreshnessMetadata
import com.intellitrip.contracts.ProviderResult
import com.intellitrip.contracts.RoutingProvider
import com.intellitrip.domain.FeedId
import com.intellitrip.domain.FeedMetadata
import com.intellitrip.domain.JourneyOption
import com.intellitrip.domain.TripPlanRequest
import com.intellitrip.engine.AtlasEngine
import com.intellitrip.engine.AtlasProviders
import com.intellitrip.gtfs.GtfsFeedAcquirer
import com.intellitrip.gtfs.PlatformFileStore
import com.intellitrip.gtfs.StaticFeedSnapshotStore
import com.intellitrip.routing.RoutingNetwork
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.file.Files
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.isActive
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.time.Duration

class AtlasNativeBridgeTest {

    private val tempDirs = mutableListOf<File>()

    @After
    fun tearDown() {
        tempDirs.forEach { it.deleteRecursively() }
        tempDirs.clear()
    }

    private sealed interface ReplyOutcome {
        data class Success(val value: Any?) : ReplyOutcome
        data class Error(val code: String, val message: String?, val details: Any?) : ReplyOutcome
    }

    private fun awaitMethod(
        bridge: AtlasNativeBridge,
        method: String,
        args: Map<String, Any?> = emptyMap(),
        timeoutSeconds: Long = 10L,
    ): ReplyOutcome {
        val future = CompletableFuture<ReplyOutcome>()
        bridge.dispatchMethod(
            method = method,
            arguments = args,
            result = object : BridgeResult {
                override fun success(value: Any?) {
                    future.complete(ReplyOutcome.Success(value))
                }

                override fun error(code: String, message: String?, details: Any?) {
                    future.complete(ReplyOutcome.Error(code, message, details))
                }
            },
        )
        return future.get(timeoutSeconds, TimeUnit.SECONDS)
    }

    private fun newSnapshotStore(): StaticFeedSnapshotStore {
        val dir = Files.createTempDirectory("atlas-bridge-test").toFile()
        tempDirs += dir
        return StaticFeedSnapshotStore(PlatformFileStore(dir.absolutePath))
    }

    private fun testNetwork(
        validFrom: LocalDate = LocalDate(2026, 11, 14),
        validTo: LocalDate = LocalDate(2027, 1, 1),
        fetchedAt: Instant = Instant.parse("2026-11-14T08:55:36Z"),
    ): RoutingNetwork {
        val fid = FeedId("metro-transit-regional")
        return RoutingNetwork(
            feedId = fid,
            metadata = FeedMetadata(
                feedId = fid,
                publisherName = "Metro Transit",
                publisherUrl = null,
                lang = "en",
                version = "test-1",
                hash = "test-hash",
                fetchedAt = fetchedAt,
                validFrom = validFrom,
                validTo = validTo,
                sourceUrl = "asset://gtfs/metro_transit_regional.zip",
            ),
            routes = emptyList(),
            stops = emptyList(),
            trips = emptyList(),
        )
    }

    private fun buildMinimalGtfsZip(
        startDate: String = "20261114",
        endDate: String = "20270101",
    ): ByteArray {
        val files = linkedMapOf(
            "agency.txt" to """
                agency_id,agency_name,agency_url,agency_timezone
                MT,Metro Transit,https://www.metrotransit.org,America/Chicago
            """.trimIndent(),
            "stops.txt" to """
                stop_id,stop_name,stop_lat,stop_lon
                S1,Lake & Hennepin,44.9484,-93.2982
                S2,Nicollet & Lake,44.9484,-93.2778
                S3,Nicollet & 7th,44.9765,-93.2725
            """.trimIndent(),
            "routes.txt" to """
                route_id,agency_id,route_short_name,route_long_name,route_type
                R21,MT,21,Uptown - Lake St,3
                R18,MT,18,Nicollet Ave,3
            """.trimIndent(),
            "calendar.txt" to """
                service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date
                SVC1,1,1,1,1,1,1,1,$startDate,$endDate
            """.trimIndent(),
            "trips.txt" to """
                route_id,service_id,trip_id
                R21,SVC1,T21
                R18,SVC1,T18
            """.trimIndent(),
            "stop_times.txt" to """
                trip_id,arrival_time,departure_time,stop_id,stop_sequence
                T21,08:00:00,08:00:00,S1,1
                T21,08:10:00,08:10:00,S2,2
                T18,08:15:00,08:15:00,S2,1
                T18,08:30:00,08:30:00,S3,2
            """.trimIndent(),
        )
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zip ->
            for ((name, body) in files) {
                zip.putNextEntry(ZipEntry(name))
                zip.write(body.toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }
        }
        return out.toByteArray()
    }

    private fun testBridge(
        clock: () -> Instant = { Instant.parse("2026-11-16T13:30:00Z") },
        bundledZip: ByteArray? = null,
        feedSourceUrl: String = "https://example.test/gtfs/${UUID.randomUUID()}.zip",
        httpTransportFactory: (() -> GtfsFeedAcquirer.HttpTransport)? = null,
    ): AtlasNativeBridge = AtlasNativeBridge(
        context = null,
        clock = clock,
        plannerDispatcher = Dispatchers.Default,
        ioDispatcher = Dispatchers.IO,
        mainDispatcher = Dispatchers.Default,
        feedSourceUrl = feedSourceUrl,
        snapshotStoreOverride = newSnapshotStore(),
        bundledAssetOpener = bundledZip?.let { bytes -> { bytes } },
        httpTransportFactory = httpTransportFactory,
    )

    @Test
    fun singleReplyBridgeResultForwardsOnlyFirstCompletion() {
        val successes = AtomicInteger(0)
        val errors = AtomicInteger(0)
        val single = SingleReplyBridgeResult(
            object : BridgeResult {
                override fun success(value: Any?) {
                    successes.incrementAndGet()
                }

                override fun error(code: String, message: String?, details: Any?) {
                    errors.incrementAndGet()
                }
            },
        )
        single.success(mapOf("ok" to true))
        single.success(mapOf("ok" to false))
        single.error("CANCELED", "late", null)

        assertEquals(1, successes.get())
        assertEquals(0, errors.get())
    }

    @Test
    fun preDispatchCancelAbortsWithoutLaunchingCpuWorkAndIsIdempotent() {
        val planCalls = AtomicInteger(0)
        val provider = object : RoutingProvider {
            override val providerId = "spy"
            override suspend fun plan(request: TripPlanRequest): ProviderResult<List<JourneyOption>> {
                planCalls.incrementAndGet()
                return ProviderResult.Success(
                    emptyList(),
                    FreshnessMetadata(Instant.DISTANT_PAST, Instant.DISTANT_PAST, Duration.ZERO, "spy"),
                )
            }
        }
        val bridge = testBridge()
        bridge.installEngineForTesting(
            AtlasEngine(FeedId("metro-transit-regional"), AtlasProviders(routing = provider), offlineAvailable = true),
            testNetwork(),
        )

        val firstCancel = awaitMethod(bridge, "cancelRequest", mapOf("requestId" to "req-pre-1"))
        val cancelSuccess = firstCancel as ReplyOutcome.Success
        assertEquals(false, (cancelSuccess.value as Map<*, *>)["cancelRequested"])

        val planOutcome = awaitMethod(
            bridge,
            "planJourney",
            mapOf(
                "requestId" to "req-pre-1",
                "meetingId" to "m1",
                "origin" to mapOf("lat" to 44.9484, "lon" to -93.2982),
                "destination" to mapOf("lat" to 44.9765, "lon" to -93.2725),
                "departAtUtcMs" to Instant.parse("2026-11-16T13:45:00Z").toEpochMilliseconds(),
            ),
        )
        val error = planOutcome as ReplyOutcome.Error
        assertEquals("CANCELED", error.code)
        assertEquals(0, planCalls.get())

        val repeatCancel = awaitMethod(bridge, "cancelRequest", mapOf("requestId" to "req-pre-1")) as ReplyOutcome.Success
        assertEquals(false, (repeatCancel.value as Map<*, *>)["cancelRequested"])
    }

    @Test
    fun midFlightCancelStopsNativeCoroutineAndIsIdempotent() {
        val startedLatch = CountDownLatch(1)
        val cancelledLatch = CountDownLatch(1)
        val completedWithoutCancel = AtomicInteger(0)

        val cooperativeProvider = object : RoutingProvider {
            override val providerId = "cooperative-slow"
            override suspend fun plan(request: TripPlanRequest): ProviderResult<List<JourneyOption>> {
                startedLatch.countDown()
                try {
                    while (kotlin.coroutines.coroutineContext.isActive) {
                        kotlin.coroutines.coroutineContext.ensureActive()
                        delay(20)
                    }
                    completedWithoutCancel.incrementAndGet()
                } catch (e: CancellationException) {
                    cancelledLatch.countDown()
                    throw e
                }
                return ProviderResult.Success(
                    emptyList(),
                    FreshnessMetadata(Instant.DISTANT_PAST, Instant.DISTANT_PAST, Duration.ZERO, "cooperative-slow"),
                )
            }
        }

        val bridge = testBridge()
        bridge.installEngineForTesting(
            AtlasEngine(
                FeedId("metro-transit-regional"),
                AtlasProviders(routing = cooperativeProvider),
                offlineAvailable = true,
            ),
            testNetwork(),
        )

        val replyCount = AtomicInteger(0)
        val planFuture = CompletableFuture<ReplyOutcome>()
        bridge.dispatchMethod(
            method = "planJourney",
            arguments = mapOf(
                "requestId" to "req-mid-1",
                "meetingId" to "m1",
                "origin" to mapOf("lat" to 44.9484, "lon" to -93.2982),
                "destination" to mapOf("lat" to 44.9765, "lon" to -93.2725),
                "departAtUtcMs" to Instant.parse("2026-11-16T13:45:00Z").toEpochMilliseconds(),
                "timeoutMs" to 10_000,
            ),
            result = object : BridgeResult {
                override fun success(value: Any?) {
                    replyCount.incrementAndGet()
                    planFuture.complete(ReplyOutcome.Success(value))
                }

                override fun error(code: String, message: String?, details: Any?) {
                    replyCount.incrementAndGet()
                    planFuture.complete(ReplyOutcome.Error(code, message, details))
                }
            },
        )

        assertTrue("Expected native planner to start", startedLatch.await(5, TimeUnit.SECONDS))

        val firstCancel = awaitMethod(bridge, "cancelRequest", mapOf("requestId" to "req-mid-1")) as ReplyOutcome.Success
        assertEquals(true, (firstCancel.value as Map<*, *>)["cancelRequested"])

        val secondCancel = awaitMethod(bridge, "cancelRequest", mapOf("requestId" to "req-mid-1")) as ReplyOutcome.Success
        assertEquals(false, (secondCancel.value as Map<*, *>)["cancelRequested"])

        val outcome = planFuture.get(5, TimeUnit.SECONDS) as ReplyOutcome.Error
        assertEquals("CANCELED", outcome.code)
        assertTrue("Expected cooperative coroutine cancellation", cancelledLatch.await(5, TimeUnit.SECONDS))
        assertEquals(0, completedWithoutCancel.get())
        assertEquals(1, replyCount.get())
    }

    @Test
    fun deadlineExpirationReturnsTimeoutDistinctFromCanceled() {
        val slowProvider = object : RoutingProvider {
            override val providerId = "slow"
            override suspend fun plan(request: TripPlanRequest): ProviderResult<List<JourneyOption>> {
                delay(2_000)
                return ProviderResult.Success(
                    emptyList(),
                    FreshnessMetadata(Instant.DISTANT_PAST, Instant.DISTANT_PAST, Duration.ZERO, "slow"),
                )
            }
        }
        val bridge = testBridge()
        bridge.installEngineForTesting(
            AtlasEngine(
                FeedId("metro-transit-regional"),
                AtlasProviders(routing = slowProvider),
                offlineAvailable = true,
            ),
            testNetwork(),
        )

        val outcome = awaitMethod(
            bridge,
            "planJourney",
            mapOf(
                "requestId" to "req-to-1",
                "meetingId" to "m1",
                "origin" to mapOf("lat" to 44.9484, "lon" to -93.2982),
                "destination" to mapOf("lat" to 44.9765, "lon" to -93.2725),
                "departAtUtcMs" to Instant.parse("2026-11-16T13:45:00Z").toEpochMilliseconds(),
                "timeoutMs" to 80,
            ),
        ) as ReplyOutcome.Error

        assertEquals("TIMEOUT", outcome.code)
        val details = outcome.details as Map<*, *>
        assertEquals("req-to-1", details["requestId"])
        assertEquals(80L, (details["timeoutMs"] as Number).toLong())
    }

    @Test
    fun skipsSecondTransferRetryWhenOriginHasNoStopsWithinWalkLimit() {
        val requestedTransfers = java.util.Collections.synchronizedList(mutableListOf<Int>())
        val missingOriginProvider = object : RoutingProvider {
            override val providerId = "missing-stops"
            override suspend fun plan(request: TripPlanRequest): ProviderResult<List<JourneyOption>> {
                requestedTransfers.add(request.maxTransfers ?: -1)
                return ProviderResult.PartialResult(
                    data = emptyList(),
                    missing = listOf("stops-within-walk-limit", "no-origin-stops-within-walk-limit"),
                    freshness = FreshnessMetadata(Instant.DISTANT_PAST, Instant.DISTANT_PAST, Duration.ZERO, "missing-stops"),
                )
            }
        }
        val bridge = testBridge()
        bridge.installEngineForTesting(
            AtlasEngine(
                FeedId("metro-transit-regional"),
                AtlasProviders(routing = missingOriginProvider),
                offlineAvailable = true,
            ),
            testNetwork(),
        )

        val outcome = awaitMethod(
            bridge,
            "planJourney",
            mapOf(
                "requestId" to "req-nocov-1",
                "meetingId" to "m1",
                "origin" to mapOf("lat" to 45.50, "lon" to -94.00),
                "destination" to mapOf("lat" to 44.9765, "lon" to -93.2725),
                "departAtUtcMs" to Instant.parse("2026-11-16T13:45:00Z").toEpochMilliseconds(),
            ),
        ) as ReplyOutcome.Error

        assertEquals("NO_ITINERARY", outcome.code)
        assertEquals(listOf(1), requestedTransfers)
        val details = outcome.details as Map<*, *>
        val missingReasons = details["missingReasons"] as List<*>
        assertTrue(missingReasons.contains("no-origin-stops-within-walk-limit"))
        assertTrue(missingReasons.contains("stops-within-walk-limit"))
    }

    @Test
    fun retriesSecondTransferOnlyForNonCoverageUnavailableOutcomes() {
        val requestedTransfers = java.util.Collections.synchronizedList(mutableListOf<Int>())
        val noRouteProvider = object : RoutingProvider {
            override val providerId = "no-route"
            override suspend fun plan(request: TripPlanRequest): ProviderResult<List<JourneyOption>> {
                requestedTransfers.add(request.maxTransfers ?: -1)
                return ProviderResult.PartialResult(
                    data = emptyList(),
                    missing = listOf("no-connecting-trip-found"),
                    freshness = FreshnessMetadata(Instant.DISTANT_PAST, Instant.DISTANT_PAST, Duration.ZERO, "no-route"),
                )
            }
        }
        val bridge = testBridge()
        bridge.installEngineForTesting(
            AtlasEngine(
                FeedId("metro-transit-regional"),
                AtlasProviders(routing = noRouteProvider),
                offlineAvailable = true,
            ),
            testNetwork(),
        )

        val outcome = awaitMethod(
            bridge,
            "planJourney",
            mapOf(
                "requestId" to "req-retry-1",
                "meetingId" to "m1",
                "origin" to mapOf("lat" to 44.9484, "lon" to -93.2982),
                "destination" to mapOf("lat" to 44.9765, "lon" to -93.2725),
                "departAtUtcMs" to Instant.parse("2026-11-16T13:45:00Z").toEpochMilliseconds(),
            ),
        ) as ReplyOutcome.Error

        assertEquals("NO_ITINERARY", outcome.code)
        assertEquals(listOf(1, 2), requestedTransfers)
    }

    @Test
    fun staticNetworkPlansRealTransferItineraryAndReportsMissingOriginCoverage() {
        val zone = TimeZone.of("America/Chicago")
        val clockTime = LocalDateTime(2026, 11, 16, 7, 30).toInstant(zone)
        val bridge = testBridge(
            clock = { clockTime },
            bundledZip = buildMinimalGtfsZip(startDate = "20261114", endDate = "20270101"),
        )

        val loadResult = awaitMethod(bridge, "loadStaticNetwork", mapOf("feedId" to "default", "fromCacheOnly" to true))
            as ReplyOutcome.Success
        val status = loadResult.value as Map<*, *>
        assertEquals("ready", status["state"])
        assertEquals(3, (status["stopCount"] as Number).toInt())

        val departAtMs = LocalDateTime(2026, 11, 16, 7, 45).toInstant(zone).toEpochMilliseconds()
        val planSuccess = awaitMethod(
            bridge,
            "planJourney",
            mapOf(
                "requestId" to "req-valid-1",
                "meetingId" to "m-downtown",
                "origin" to mapOf("lat" to 44.9484, "lon" to -93.2982),
                "destination" to mapOf("lat" to 44.9765, "lon" to -93.2725),
                "departAtUtcMs" to departAtMs,
            ),
        ) as ReplyOutcome.Success

        val payload = planSuccess.value as Map<*, *>
        assertEquals(false, payload["isSynthetic"])
        assertEquals("static_gtfs", payload["dataSource"])
        val options = payload["options"] as List<*>
        assertTrue("Expected at least one multi-stop transit option", options.isNotEmpty())
        val firstOption = options.first() as Map<*, *>
        val legs = firstOption["legs"] as List<*>
        val transitLegs = legs.filterIsInstance<Map<*, *>>().filter { it["mode"] == "bus" }
        assertEquals(2, transitLegs.size)
        assertEquals("21", transitLegs[0]["routeLabel"])
        assertEquals("18", transitLegs[1]["routeLabel"])

        val uncoveredError = awaitMethod(
            bridge,
            "planJourney",
            mapOf(
                "requestId" to "req-far-1",
                "meetingId" to "m-downtown",
                "origin" to mapOf("lat" to 45.5600, "lon" to -94.1600),
                "destination" to mapOf("lat" to 44.9765, "lon" to -93.2725),
                "departAtUtcMs" to departAtMs,
            ),
        ) as ReplyOutcome.Error
        assertEquals("NO_ITINERARY", uncoveredError.code)
        val details = uncoveredError.details as Map<*, *>
        val missingReasons = details["missingReasons"] as List<*>
        assertTrue(missingReasons.contains("no-origin-stops-within-walk-limit"))
        assertTrue(missingReasons.contains("stops-within-walk-limit"))
    }

    @Test
    fun feedExpirationBoundaryAndConsentGatedRefreshWorkDeterministically() {
        val zone = TimeZone.of("America/Chicago")
        var currentTime = LocalDateTime(2027, 1, 1, 23, 59, 59).toInstant(zone)
        val refreshedHttpCalls = AtomicInteger(0)
        val refreshedZip = buildMinimalGtfsZip(startDate = "20261215", endDate = "20270401")

        val bridge = testBridge(
            clock = { currentTime },
            bundledZip = buildMinimalGtfsZip(startDate = "20261114", endDate = "20270101"),
            httpTransportFactory = {
                GtfsFeedAcquirer.HttpTransport { _ ->
                    refreshedHttpCalls.incrementAndGet()
                    GtfsFeedAcquirer.HttpResponse(
                        status = 200,
                        body = refreshedZip,
                        headers = mapOf("ETag" to "\"wo2b-refreshed-v2\""),
                    )
                }
            },
        )

        val loadResult = awaitMethod(bridge, "loadStaticNetwork", mapOf("feedId" to "default")) as ReplyOutcome.Success
        assertEquals("ready", (loadResult.value as Map<*, *>)["state"])

        val capsBeforeExpiry = (awaitMethod(bridge, "getCapabilities") as ReplyOutcome.Success).value as Map<*, *>
        assertEquals(true, capsBeforeExpiry["localRouting"])

        // Cross local midnight past 2027-01-01 using injected clock (no device clock change).
        currentTime = LocalDateTime(2027, 1, 2, 0, 0, 5).toInstant(zone)

        val capsAfterExpiry = (awaitMethod(bridge, "getCapabilities") as ReplyOutcome.Success).value as Map<*, *>
        assertEquals(false, capsAfterExpiry["localRouting"])
        assertEquals(true, capsAfterExpiry["offlineSnapshot"])

        val offlineExpired = (awaitMethod(bridge, "getOfflineStatus") as ReplyOutcome.Success).value as Map<*, *>
        assertEquals("expired", offlineExpired["staticNetwork"])
        assertEquals("unavailable", offlineExpired["routing"])

        val expiredPlan = awaitMethod(
            bridge,
            "planJourney",
            mapOf(
                "requestId" to "req-exp-1",
                "meetingId" to "m-downtown",
                "origin" to mapOf("lat" to 44.9484, "lon" to -93.2982),
                "destination" to mapOf("lat" to 44.9765, "lon" to -93.2725),
                "departAtUtcMs" to LocalDateTime(2027, 1, 2, 7, 45).toInstant(zone).toEpochMilliseconds(),
            ),
        ) as ReplyOutcome.Error
        assertEquals("FEED_EXPIRED", expiredPlan.code)

        // Refresh without explicit consent fails closed with zero HTTP traffic.
        val unconsentedRefresh = awaitMethod(
            bridge,
            "refreshStaticFeed",
            mapOf("feedId" to "default", "userConsented" to false),
        ) as ReplyOutcome.Error
        assertEquals("PERMISSION_REQUIRED", unconsentedRefresh.code)
        assertEquals(0, refreshedHttpCalls.get())

        // Consented refresh installs the updated GTFS ZIP and restores planning.
        val consentedRefresh = awaitMethod(
            bridge,
            "refreshStaticFeed",
            mapOf("feedId" to "default", "userConsented" to true),
        ) as ReplyOutcome.Success
        assertEquals(1, refreshedHttpCalls.get())
        val refreshedStatus = consentedRefresh.value as Map<*, *>
        assertEquals("ready", refreshedStatus["state"])
        assertEquals("remote_gtfs_refreshed", refreshedStatus["source"])
        assertNotNull(refreshedStatus["expiresAt"])

        val capsRestored = (awaitMethod(bridge, "getCapabilities") as ReplyOutcome.Success).value as Map<*, *>
        assertEquals(true, capsRestored["localRouting"])

        val postRefreshPlan = awaitMethod(
            bridge,
            "planJourney",
            mapOf(
                "requestId" to "req-exp-2",
                "meetingId" to "m-downtown",
                "origin" to mapOf("lat" to 44.9484, "lon" to -93.2982),
                "destination" to mapOf("lat" to 44.9765, "lon" to -93.2725),
                "departAtUtcMs" to LocalDateTime(2027, 1, 2, 7, 45).toInstant(zone).toEpochMilliseconds(),
            ),
        ) as ReplyOutcome.Success
        val refreshedOptions = (postRefreshPlan.value as Map<*, *>)["options"] as List<*>
        assertTrue(refreshedOptions.isNotEmpty())
        assertFalse(refreshedOptions.isEmpty())
    }
}
