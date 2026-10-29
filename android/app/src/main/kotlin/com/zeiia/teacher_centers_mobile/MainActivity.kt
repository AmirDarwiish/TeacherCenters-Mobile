package com.zeiia.teacher_centers_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("rewaq_chat", "رسائل رواق", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "رسائل المحادثات وجروبات الحصص"
            channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
