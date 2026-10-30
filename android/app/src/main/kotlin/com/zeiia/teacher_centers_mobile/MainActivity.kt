package com.zeiia.teacher_centers_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.common.GoogleApiAvailabilityLight

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rewaq/push_environment").setMethodCallHandler { call, result ->
            if (call.method != "status") { result.notImplemented() }
            else {
                val manager = getSystemService(NotificationManager::class.java)
                val channel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) manager.getNotificationChannel("rewaq_chat") else null
                result.success(mapOf(
                    "googlePlayStatus" to GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(this),
                    "chatChannelEnabled" to (channel == null || channel.importance != NotificationManager.IMPORTANCE_NONE)
                ))
            }
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("rewaq_chat", "رسائل رواق", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "رسائل المحادثات وجروبات الحصص"
            channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
            val updates = NotificationChannel("rewaq_updates", "تحديثات رواق", NotificationManager.IMPORTANCE_HIGH)
            updates.description = "الكورسات والواجبات والحصص وإعلانات المدرس"
            updates.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            getSystemService(NotificationManager::class.java).createNotificationChannel(updates)
        }
    }
}
