package com.Phisher98

import com.lagradost.cloudstream3.MainAPI
import com.lagradost.cloudstream3.plugins.BasePlugin
import com.lagradost.cloudstream3.plugins.CloudstreamPlugin

private val Cinemana.Cinmana: MainAPI

@CloudstreamPlugin
class Cinemana: BasePlugin() {
    override fun load() {
        registerMainAPI(Cinmana)
    }
}