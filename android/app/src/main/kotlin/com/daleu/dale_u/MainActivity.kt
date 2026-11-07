package com.daleu.dale_u

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createProximityChannel()
    }

    /**
     * Canal de "Tu panadero está cerca". Como mucho llegan dos avisos por
     * visita (200 m y 40 m), por eso puede sonar y asomarse arriba.
     */
    private fun createProximityChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Panadero cerca",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Aviso cuando tu panadero está a 200 m y a 40 m de tu casa."
        }
        manager.createNotificationChannel(channel)
    }

    private companion object {
        const val CHANNEL_ID = "panadero_cerca"
    }
}
