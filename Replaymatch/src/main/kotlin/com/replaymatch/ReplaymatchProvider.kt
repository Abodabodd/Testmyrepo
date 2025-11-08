package com.replaymatch

import android.content.Context
import com.lagradost.cloudstream3.plugins.CloudstreamPlugin
import com.lagradost.cloudstream3.plugins.Plugin

@CloudstreamPlugin
class ReplaymatchProvider : Plugin() {
    override fun load(context: Context) {
        registerMainAPI(FullMatchShowsProvider())

    }
}
