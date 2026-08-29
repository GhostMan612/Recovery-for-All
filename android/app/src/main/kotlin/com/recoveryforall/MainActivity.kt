// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

package com.recoveryforall

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.content.Intent
import android.os.Build
import android.os.Bundle
import com.recoveryforall.StepCounterForegroundService
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterFragmentActivity() {
    private const val STEP_COUNTER_CHANNEL = "com.example.recovery_companion/step_counter"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupStepCounterChannel()
    }

    private fun setupStepCounterChannel() {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.recovery_companion/step_counter").setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val intent = Intent(this, StepCounterForegroundService::class.java)
                    intent.action = StepCounterForegroundService.ACTION_START
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopForegroundService" -> {
                    val intent = Intent(this, StepCounterForegroundService::class.java)
                    intent.action = StepCounterForegroundService.ACTION_STOP
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}