package com.recoveryforall

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

class StepCounterForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "step_counter_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "START_STEP_COUNTER"
        const val ACTION_STOP = "STOP_STEP_COUNTER"
        const val METHOD_CHANNEL = "com.example.recovery_companion/step_counter"
    }

    private var methodChannel: MethodChannel? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        
        when (action) {
            ACTION_START -> startForegroundService()
            ACTION_STOP -> stopForegroundService()
        }
        
        return START_STICKY
    }

    private fun startForegroundService() {
        val notification = createNotification()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        
        // Keep the pedometer streams alive
        // The actual pedometer streams are managed by Flutter via MethodChannel
    }

    private fun stopForegroundService() {
        stopForeground(true)
        stopSelf()
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Step Counter Active")
            .setContentText("Tracking your steps in the background")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Step Counter",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background step counting for walk verification"
                importance = NotificationManager.IMPORTANCE_LOW
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            }
            
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
    }
}