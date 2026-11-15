// android/app/src/test/kotlin/com/recoveryforall/atlas/AtlasChannelAdapterTest.kt
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

package com.recoveryforall.atlas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AtlasChannelAdapterTest {

    private fun invokeFallback(
        method: String,
        arguments: Map<String, Any?>? = emptyMap(),
        sdkInt: Int = 24,
    ): String {
        val adapter = AtlasChannelAdapter.fallbackForTesting { sdkInt }
        var outcome = ""
        adapter.dispatchFallback(
            method = method,
            arguments = arguments,
            onSuccess = { value -> outcome = "SUCCESS:$value" },
            onError = { code, message, details -> outcome = "ERROR:$code:$message:$details" },
            onNotImplemented = { outcome = "NOT_IMPLEMENTED" },
        )
        return outcome
    }

    @Test
    fun refreshStaticFeedRequiresConsentAndReturnsTypedSdkNotInstalledOnApi24() {
        val noConsent = invokeFallback(
            method = "refreshStaticFeed",
            arguments = mapOf("feedId" to "default", "userConsented" to false),
            sdkInt = 24,
        )
        assertTrue("Expected PERMISSION_REQUIRED, got $noConsent", noConsent.startsWith("ERROR:PERMISSION_REQUIRED:"))

        val consented = invokeFallback(
            method = "refreshStaticFeed",
            arguments = mapOf("feedId" to "default", "userConsented" to true),
            sdkInt = 24,
        )
        assertTrue("Expected SDK_NOT_INSTALLED, got $consented", consented.startsWith("ERROR:SDK_NOT_INSTALLED:"))
        assertTrue("Expected API 24 mentioned in $consented", consented.contains("API 24"))
        assertTrue("Expected apiLevel=24 details in $consented", consented.contains("apiLevel=24"))
    }

    @Test
    fun planJourneyAndCancelStayTruthfulWithoutDelegate() {
        val planOutcome = invokeFallback(
            method = "planJourney",
            arguments = mapOf(
                "meetingId" to "m1",
                "origin" to mapOf("lat" to 44.95, "lon" to -93.29),
                "destination" to mapOf("lat" to 44.97, "lon" to -93.27),
            ),
            sdkInt = 25,
        )
        assertTrue(planOutcome.startsWith("ERROR:SDK_NOT_INSTALLED:"))
        assertTrue(planOutcome.contains("apiLevel=25"))

        val cancelOutcome = invokeFallback(
            method = "cancelRequest",
            arguments = mapOf("requestId" to "req-1"),
            sdkInt = 24,
        )
        assertEquals("SUCCESS:{cancelRequested=false, requestId=req-1}", cancelOutcome)
        assertFalse(cancelOutcome.contains("cancelRequested=true"))
    }

    @Test
    fun unknownMethodFallsBackToNotImplemented() {
        assertEquals("NOT_IMPLEMENTED", invokeFallback("doesNotExist", emptyMap(), sdkInt = 24))
    }
}
