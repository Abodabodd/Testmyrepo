package com.arabseed

// تأكد من أن هذه الاستيرادات موجودة في الأعلى
import com.lagradost.cloudstream3.extractors.loadAllLinks
import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*
import android.util.Log

class Arabseed : MainAPI() {
    override var mainUrl = "https://a.asd.homes"
    override var name = "ArabSeed"
    override var lang = "ar"
    override val hasMainPage = true
    override val supportedTypes = setOf(TvType.TvSeries, TvType.Movie)

    // ... (ضع هنا باقي دوال الـ search و load وغيرها إذا كانت موجودة) ...

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val doc = app.get(data).document
        val iframeSrc = doc.select("div.player__iframe iframe").attr("src")

        if (iframeSrc.isNotEmpty()) {
            Log.d("ArabSeed", "Found iframe source: $iframeSrc")

            // هذا السطر سيعمل بعد الخطوة التالية
            return loadAllLinks(
                url = iframeSrc,
                name = this.name,
                referer = data,
                subtitleCallback = subtitleCallback,
                callback = callback
            )
        }

        Log.w("ArabSeed", "No iframe found for: $data")
        return false
    }
}