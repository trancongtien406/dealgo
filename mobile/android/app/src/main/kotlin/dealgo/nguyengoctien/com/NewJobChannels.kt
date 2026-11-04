package dealgo.nguyengoctien.com

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build

/**
 * Notification channels for new-job pushes (r26). The backend sets FCM
 * android.notification.channel_id to one of these (backend NEW_JOB_SOUNDS).
 * A channel's sound cannot change after creation: a new sound file needs a new `_vN` id.
 */
object NewJobChannels {
    /** channel id → (raw sound name or null for the system default, user-visible name). */
    val CHANNELS: List<Triple<String, String?, String>> = listOf(
        Triple("dealgo_new_ride_v1", "dealgo_new_ride", "Cuốc xe mới"),
        Triple("dealgo_new_food_job_v1", "dealgo_new_food_job", "Đơn giao đồ ăn mới"),
        Triple("dealgo_merchant_new_order_v1", "dealgo_merchant_new_order", "Quán có đơn mới"),
        Triple("dealgo_new_job_default_v1", null, "Cuốc/đơn mới (âm mặc định)"),
    )

    fun ensure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        for ((id, sound, name) in CHANNELS) {
            if (manager.getNotificationChannel(id) != null) continue
            val channel = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Âm báo khi có cuốc hoặc đơn mới"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 400, 200, 400)
                val uri = if (sound != null) {
                    Uri.parse("android.resource://${context.packageName}/raw/$sound")
                } else {
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                }
                setSound(uri, attributes)
            }
            manager.createNotificationChannel(channel)
        }
    }
}

