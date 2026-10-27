package io.github.damsowe.damso_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createInquiryChannel()
    }

    /**
     * 문의 알림 채널(중요도 높음). 긴급 문의 알림이 화면 위로 뜨도록 한다.
     * AndroidManifest 의 default_notification_channel_id 와 같은 ID 다(specs/002 research R9).
     */
    private fun createInquiryChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            INQUIRY_CHANNEL_ID,
            "문의 알림",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = "새 문의와 긴급 문의를 알려 드려요." }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        const val INQUIRY_CHANNEL_ID = "damso_inquiry"
    }
}
