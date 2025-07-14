package com.cinemana.provider

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*
import kotlinx.serialization.json.*

class CinemanaProvider : MainAPI() {
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var name = "Cinemana"
    override val hasMainPage = true
    override var lang = "ar"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    override val mainPage = mainPageOf(
        "$mainUrl/movies" to "أفلام",
        "$mainUrl/series" to "مسلسلات"
    )

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val document = app.get(request.data).document
        val items = document.select(".card").mapNotNull {
            val title = it.selectFirst(".card-title")?.text() ?: return@mapNotNull null
            val href = it.selectFirst("a")?.attr("href") ?: return@mapNotNull null
            val poster = it.selectFirst("img")?.attr("src")
            newAnimeSearchResponse(title, href) {
                this.posterUrl = poster
            }
        }
        return newHomePageResponse(request.name, items)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val url = "$mainUrl/search?q=$query"
        val document = app.get(url).document
        return document.select(".card").mapNotNull {
            val title = it.selectFirst(".card-title")?.text() ?: return@mapNotNull null
            val href = it.selectFirst("a")?.attr("href") ?: return@mapNotNull null
            val poster = it.selectFirst("img")?.attr("src")
            newAnimeSearchResponse(title, href) {
                this.posterUrl = poster
            }
        }
    }

    override suspend fun load(url: String): LoadResponse {
        val doc = app.get(url).document
        val title = doc.selectFirst(".video-title")?.text() ?: "Unknown"
        val poster = doc.selectFirst("img.cover")?.attr("src")
        val description = doc.selectFirst(".description")?.text()
        val apiId = url.substringAfterLast("/") // crude example
        val apiUrl = "$mainUrl/api/android/allVideoInfo/id/$apiId"

        return newMovieLoadResponse(title, apiUrl, TvType.Movie, apiUrl) {
            this.posterUrl = poster
            this.plot = description
        }
    }

    private fun getQualityFromName(name: String): Int {
        return Regex("(\\d{3,4})").find(name)?.groupValues?.get(1)?.toIntOrNull() ?: Qualities.Unknown.value
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ) {
        val response = app.get(data, referer = data).text
        val root = tryParseJson(response)?.jsonObject ?: return

        val videos = root["videos"]?.jsonArray ?: return
        videos.forEach { elem ->
            val obj = elem.jsonObject
            val videoUrl = obj["videoUrl"]?.jsonPrimitive?.content ?: return@forEach
            val qualityName = obj["quality"]?.jsonPrimitive?.content ?: "Default"
            callback(
                ExtractorLink(
                    name,
                    "Cinemana",
                    videoUrl,
                    referer = data,
                    quality = getQualityFromName(qualityName),
                    isM3u8 = videoUrl.endsWith(".m3u8")
                )
            )
        }

        root["subtitles"]?.jsonArray?.forEach { subElem ->
            val subObj = subElem.jsonObject
            val lang = subObj["language"]?.jsonPrimitive?.content ?: "Subtitle"
            val subUrl = subObj["url"]?.jsonPrimitive?.content ?: return@forEach
            subtitleCallback(SubtitleFile(lang, subUrl))
        }
    }
}
