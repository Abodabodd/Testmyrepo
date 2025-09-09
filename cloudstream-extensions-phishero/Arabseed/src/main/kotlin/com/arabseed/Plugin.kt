package com.arabseed

import com.lagradost.cloudstream3.plugins.BasePlugin
import com.lagradost.cloudstream3.plugins.CloudstreamPlugin

@CloudstreamPlugin
class ArabSeedPlugin : BasePlugin() {
    override fun load() {
        registerMainAPI(ArabSeed())
        registerExtractorAPI(ArabSeedExtractor())
    }
}
