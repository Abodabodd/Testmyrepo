package com.cinemana

import com.lagradost.cloudstream3.plugins.CloudstreamPlugin
import com.lagradost.cloudstream3.plugins.BasePlugin

@CloudstreamPlugin
class CinemanaPlugin : BasePlugin() {
    override fun load() {
        // سجل البروڤايدر هنا
        registerMainAPI(ShabakatyCinemanaProvider())
    }
}
