// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

package com.recoveryforall.atlas

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AtlasChannelAdapter private constructor(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "recoveryforall/atlas_v1"
        const val CURRENT_API_VERSION = 1

        fun setup(context: Context, messenger: BinaryMessenger): AtlasChannelAdapter {
            val adapter = AtlasChannelAdapter(context)
            val channel = MethodChannel(messenger, CHANNEL_NAME)
            channel.setMethodCallHandler(adapter)
            return adapter
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val apiVersion = call.argument<Int>("apiVersion") ?: CURRENT_API_VERSION
        if (apiVersion != CURRENT_API_VERSION) {
            result.error("UNSUPPORTED_VERSION", "API version $apiVersion is not supported (expected $CURRENT_API_VERSION)", null)
            return
        }

        when (call.method) {
            "getCapabilities" -> {
                val capabilities = mapOf(
                    "version" to CURRENT_API_VERSION,
                    "staticTransit" to false,
                    "localRouting" to false,
                    "realtime" to false,
                    "weather" to false,
                    "offlineSnapshot" to false,
                    "providerIds" to emptyList<String>()
                )
                result.success(capabilities)
            }

            "loadStaticNetwork" -> {
                val feedId = call.argument<String>("feedId") ?: "unknown"
                val fromCacheOnly = call.argument<Boolean>("fromCacheOnly") ?: true
                val response = mapOf(
                    "state" to "missing",
                    "feedHash" to null,
                    "fetchedAt" to null,
                    "expiresAt" to null,
                    "stopCount" to 0,
                    "source" to "unlinked_sdk"
                )
                result.success(response)
            }

            "planJourney" -> {
                // When external Atlas SDK binary artifact is unlinked, return clean typed error
                // allowing Flutter layer to gracefully engage fallback directions.
                val meetingId = call.argument<String>("meetingId") ?: ""
                val origin = call.argument<Map<String, Any?>>("origin")
                val destination = call.argument<Map<String, Any?>>("destination")

                if (origin == null || destination == null) {
                    result.error("BAD_INPUT", "Missing origin or destination coordinates", null)
                    return
                }

                result.error(
                    "SDK_NOT_INSTALLED",
                    "Atlas engine artifact is not linked. Graceful external directions fallback active.",
                    mapOf("meetingId" to meetingId, "isSynthetic" to false)
                )
            }

            "cancelRequest" -> {
                val requestId = call.argument<String>("requestId") ?: ""
                result.success(mapOf("cancelRequested" to true, "requestId" to requestId))
            }

            "getOfflineStatus" -> {
                val feedId = call.argument<String>("feedId") ?: "default"
                result.success(mapOf(
                    "staticNetwork" to "unavailable",
                    "basemap" to "cached_tiles",
                    "routing" to "unavailable",
                    "dataAgeSeconds" to null,
                    "notes" to "Atlas SDK engine not linked in local environment"
                ))
            }

            "getWeather" -> {
                result.success(mapOf("status" to "unsupported"))
            }

            else -> {
                result.notImplemented()
            }
        }
    }
}
