// android/app/src/main/kotlin/com/recoveryforall/atlas/AtlasChannelAdapter.kt
// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

package com.recoveryforall.atlas

import android.content.Context
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The single `recoveryforall/atlas_v1` channel.
 *
 * The Atlas SDK is a separate Maven artifact. Its file-backed static-feed
 * stack needs Android 8.0 (API 26); the app still serves API 24/25. This class
 * therefore contains no Atlas imports: on API 26+ it delegates to
 * [AtlasNativeBridge] through [AtlasBridgeFactory], and on older devices it
 * keeps the typed SDK_NOT_INSTALLED fallback without ever loading an Atlas
 * class.
 */
class AtlasChannelAdapter private constructor(
    private val delegate: Delegate?,
    private val sdkIntProvider: () -> Int = { Build.VERSION.SDK_INT },
) : MethodChannel.MethodCallHandler {

    internal interface Delegate : MethodChannel.MethodCallHandler

    companion object {
        const val CHANNEL_NAME = "recoveryforall/atlas_v1"
        const val CURRENT_API_VERSION = 1
        const val MIN_ATLAS_API = 26

        fun setup(context: Context, messenger: BinaryMessenger): AtlasChannelAdapter {
            val delegate = if (Build.VERSION.SDK_INT >= MIN_ATLAS_API) {
                AtlasBridgeFactory.create(context.applicationContext)
            } else {
                null
            }
            val adapter = AtlasChannelAdapter(delegate)
            MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler(adapter)
            return adapter
        }

        internal fun fallbackForTesting(sdkIntProvider: () -> Int): AtlasChannelAdapter =
            AtlasChannelAdapter(delegate = null, sdkIntProvider = sdkIntProvider)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val apiVersion = call.argument<Int>("apiVersion") ?: CURRENT_API_VERSION
        if (apiVersion != CURRENT_API_VERSION) {
            result.error(
                "UNSUPPORTED_VERSION",
                "API version $apiVersion is not supported (expected $CURRENT_API_VERSION)",
                null,
            )
            return
        }

        val active = delegate
        if (active != null) {
            active.onMethodCall(call, result)
        } else {
            fallback(call, result)
        }
    }

    /**
     * Truthful fallback for devices that cannot load the Atlas SDK. It never
     * reports a capability or cancellation that did not happen.
     */
    private fun fallback(call: MethodCall, result: MethodChannel.Result) {
        dispatchFallback(
            method = call.method,
            arguments = call.arguments as? Map<*, *>,
            onSuccess = result::success,
            onError = result::error,
            onNotImplemented = result::notImplemented,
        )
    }

    internal fun dispatchFallback(
        method: String,
        arguments: Map<*, *>?,
        onSuccess: (Any?) -> Unit,
        onError: (String, String?, Any?) -> Unit,
        onNotImplemented: () -> Unit,
    ) {
        val sdkInt = sdkIntProvider()
        when (method) {
            "getCapabilities" -> onSuccess(
                mapOf(
                    "version" to CURRENT_API_VERSION,
                    "staticTransit" to false,
                    "localRouting" to false,
                    "realtime" to false,
                    "weather" to false,
                    "offlineSnapshot" to false,
                    "providerIds" to emptyList<String>(),
                ),
            )

            "loadStaticNetwork" -> onSuccess(
                mapOf(
                    "state" to "missing",
                    "feedHash" to null,
                    "fetchedAt" to null,
                    "expiresAt" to null,
                    "stopCount" to 0,
                    "source" to "unsupported_android_version",
                ),
            )

            "refreshStaticFeed" -> {
                val userConsented = arguments?.get("userConsented") == true
                if (!userConsented) {
                    onError(
                        "PERMISSION_REQUIRED",
                        "User consent (transitFeedRefresh) is required before refreshing the transit schedule.",
                        null,
                    )
                    return
                }
                onError(
                    "SDK_NOT_INSTALLED",
                    "Atlas navigation requires Android 8.0 (API 26) or newer on this build; " +
                        "transit schedule refresh is unavailable on API $sdkInt.",
                    mapOf(
                        "apiLevel" to sdkInt,
                        "minApi" to MIN_ATLAS_API,
                    ),
                )
            }

            "planJourney" -> {
                val meetingId = arguments?.get("meetingId") as? String ?: ""
                val origin = arguments?.get("origin") as? Map<*, *>
                val destination = arguments?.get("destination") as? Map<*, *>

                if (origin == null || destination == null) {
                    onError("BAD_INPUT", "Missing origin or destination coordinates", null)
                    return
                }

                onError(
                    "SDK_NOT_INSTALLED",
                    "Atlas navigation requires Android 8.0 (API 26) or newer on this build. " +
                        "Graceful external directions fallback active.",
                    mapOf(
                        "meetingId" to meetingId,
                        "isSynthetic" to false,
                        "apiLevel" to sdkInt,
                        "minApi" to MIN_ATLAS_API,
                    ),
                )
            }

            "cancelRequest" -> {
                val requestId = arguments?.get("requestId") as? String ?: ""
                // No native journey can exist here, so never report a
                // cancellation that did not happen.
                onSuccess(mapOf("cancelRequested" to false, "requestId" to requestId))
            }

            "getOfflineStatus" -> onSuccess(
                mapOf(
                    "staticNetwork" to "unavailable",
                    "basemap" to "cached_tiles",
                    "routing" to "unavailable",
                    "dataAgeSeconds" to null,
                    "notes" to "Atlas navigation requires Android 8.0 (API 26) or newer; " +
                        "this device keeps the external-directions fallback.",
                ),
            )

            "getWeather" -> onSuccess(mapOf("status" to "unsupported"))

            else -> onNotImplemented()
        }
    }
}
