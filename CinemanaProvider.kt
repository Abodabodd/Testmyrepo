package com.cinemana

import com.lagradost.cloudstream3.plugins.BasePlugin
import com.lagradost.cloudstream3.plugins.CloudstreamPlugin

@CloudstreamPlugin
class CinemanaPlugin : BasePlugin() {
    override fun load() {
        registerMainAPI(CinemanaProvider())
    }
}
