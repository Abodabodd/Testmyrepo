package com.example

import com.lagradost.cloudstream3.plugins.BasePlugin
import com.lagradost.cloudstream3.plugins.CloudstreamPlugin

@CloudstreamPlugin
class ShabakatyCinemanaPlugin : BasePlugin() {
    override fun load() {
        // هنا نسجل المزود الخاص بنا
        registerMainAPI(ShabakatyCinemanaProvider())
    }
}
