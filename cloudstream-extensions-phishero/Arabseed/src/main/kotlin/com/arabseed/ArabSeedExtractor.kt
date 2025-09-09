package com.example.arabseed

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.extractors.ExtractorApi

class ArabSeedExtractor : ExtractorApi() {
    override val name = "ArabSeed"
    override val mainUrl = "https://w.gamehub.cam"
    override val requiresReferer = false

    override suspend fun getUrl(url: String, referer: String?): List<ExtractorLink> {
        val links = mutableListOf<ExtractorLink>()
        val res = app.get(url)
        val doc = res.document

        // اجمع كل السكربتات
        val scriptContent = doc.select("script").joinToString("\n") { it.html() }

        // Regex يمسك أي لينك فيديو m3u8/mp4
        val regex = Regex("""https.*?\.(m3u8|mp4)""")
        val matches = regex.findAll(scriptContent)

        for (match in matches) {
            val videoUrl = match.value

            links.add(
                newExtractorLink(
                    name = name,
                    source = name,
                    url = videoUrl,
                    referer = mainUrl,
                    quality = Qualities.Unknown.value,
                    isM3u8 = videoUrl.contains(".m3u8"),
                )
            )
        }

        return links
    }
}
