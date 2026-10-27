package com.trancongtien.dealgo

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // New-job sound channels must exist before the first new ride/food/store push lands.
        NewJobChannels.ensure(this)
    }
}
