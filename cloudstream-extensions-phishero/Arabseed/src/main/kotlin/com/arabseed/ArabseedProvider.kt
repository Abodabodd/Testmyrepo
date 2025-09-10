package com.arabseed

import com.lagradost.cloudstream3.plugins.CloudstreamPlugin
import com.lagradost.cloudstream3.plugins.Plugin
import android.content.Context

@CloudstreamPlugin
class ArabSeedProvider : Plugin() {
    override fun load(context: Context) {
        // هذا السطر يقوم بتسجيل الـ API الرئيسي ويحل مشكلة "class is never used"
        registerMainAPI(Arabseed())

        // قم أيضًا بتسجيل المستخرج الخاص بك

    }
}