package com.nguyenngoctien.dealgo

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.hiennv.flutter_callkit_incoming.CallkitConstants
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // New-job sound channels must exist before the first new ride/food/store push lands.
        NewJobChannels.ensure(this)
        applyLockScreenFlagsForCall(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyLockScreenFlagsForCall(intent)
    }

    /**
     * When the user answers a call from the lock-screen CallKit UI, TransparentActivity
     * brings MainActivity forward with EXTRA_CALLKIT_CALL_DATA. Without showWhenLocked,
     * MainActivity stays stuck behind the PIN pad in PAUSED state.
     */
    private fun applyLockScreenFlagsForCall(intent: Intent?) {
        val fromAcceptedCall =
            intent?.action == CallkitConstants.ACTION_CALL_ACCEPT ||
            intent?.hasExtra(FlutterCallkitIncomingPlugin.EXTRA_CALLKIT_CALL_DATA) == true
        if (!fromAcceptedCall) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }
}

