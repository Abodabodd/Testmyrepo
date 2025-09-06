package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.newExtractorLink
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

class CinemanaProvider : MainAPI() {
    override var name = "Shabakaty Cinemana"
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var lang = "ar"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val items = mutableListOf<HomePageList>()

        val moviesUrl = "$mainUrl/api/android/latestMovies/level/0/itemsPerPage/24/page/0/"
        val moviesAny = app.get(moviesUrl).parsedSafe<List<Any>>() ?: emptyList()
        val movies = moviesAny.mapNotNull { (it as? Map<String, Any>)?.toCinemanaItem()?.toSearchResponse() }
        items.add(HomePageList("أحدث الأفلام", movies))

        val seriesUrl = "$mainUrl/api/android/latestSeries/level/0/itemsPerPage/24/page/0/"
        val seriesAny = app.get(seriesUrl).parsedSafe<List<Any>>() ?: emptyList()
        val series = seriesAny.mapNotNull { (it as? Map<String, Any>)?.toCinemanaItem()?.toSearchResponse() }
        items.add(HomePageList("أحدث المسلسلات", series))

        return newHomePageResponse(items)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val moviesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Movies&videoTitle=$query"
        val moviesAny = app.get(moviesUrl).parsedSafe<List<Any>>() ?: emptyList()
        val movies = moviesAny.mapNotNull { (it as? Map<String, Any>)?.toCinemanaItem()?.toSearchResponse() }

        val seriesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Series&videoTitle=$query"
        val seriesAny = app.get(seriesUrl).parsedSafe<List<Any>>() ?: emptyList()
        val series = seriesAny.mapNotNull { (it as? Map<String, Any>)?.toCinemanaItem()?.toSearchResponse() }

        return movies + series
    }

    override suspend fun load(url: String): LoadResponse? {
        val id = url.substringAfterLast(":") // التعامل مع "cinemana:799"
        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$id"
        val detailsMap = app.get(detailsUrl).parsedSafe<Map<String, Any>>() ?: return null
        val details = detailsMap.toCinemanaItem()

        val title = details.enTitle ?: return null
        val posterUrl = details.imgObjUrl
        val plot = details.enContent
        val year = details.year?.toIntOrNull()
        val score = details.stars?.toFloatOrNull()?.let { (it / 2f * 10f).toInt() }

        return if (details.kind == 2) {
            newTvSeriesLoadResponse(title, url, TvType.TvSeries, emptyList()) {
                this.posterUrl = posterUrl
                this.plot = plot
                this.year = year
                this.score = score
            }
        } else {
            newMovieLoadResponse(title, url, TvType.Movie, url) {
                this.posterUrl = posterUrl
                this.plot = plot
                this.year = year
                this.score = score
            }
        }
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val id = data.substringAfterLast(":")
        val videosUrl = "$mainUrl/api/android/transcoddedFiles/id/$id"
        val subtitlesUrl = "$mainUrl/api/android/translationFiles/id/$id"

        app.get(videosUrl).parsedSafe<List<Any>>()?.mapNotNull { it as? Map<String, Any> }?.forEach { videoMap ->
            val videoUrl = videoMap["videoUrl"] as? String ?: return@forEach
            val resolution = videoMap["resolution"] as? String ?: "HD"
            newExtractorLink(source = name, name = resolution, url = videoUrl).let(callback)
        }

        app.get(subtitlesUrl).parsedSafe<Map<String, Any>>()?.get("translations")?.let { list ->
            (list as? List<Map<String, Any>>)?.forEach { sub ->
                val file = sub["file"] as? String ?: return@forEach
                val lang = sub["name"] as? String ?: "Unknown"
                subtitleCallback(SubtitleFile(lang, file))
            }
        }

        return true
    }

    @Serializable
    data class CinemanaItem(
        val nb: String? = null,
        @SerialName("en_title") val enTitle: String? = null,
        val imgObjUrl: String? = null,
        val year: String? = null,
        @SerialName("en_content") val enContent: String? = null,
        val stars: String? = null,
        val kind: Int? = null
    )

    private fun Map<String, Any>.toCinemanaItem(): CinemanaItem {
        return CinemanaItem(
            nb = this["nb"] as? String,
            enTitle = this["en_title"] as? String,
            imgObjUrl = this["imgObjUrl"] as? String ?: this["img"] as? String,
            year = this["year"] as? String,
            enContent = this["en_content"] as? String,
            stars = this["stars"] as? String,
            kind = (this["kind"] as? String)?.toIntOrNull() ?: (this["kind"] as? Int)
        )
    }

    private fun CinemanaItem.toSearchResponse(): SearchResponse {
        val validUrl = "cinemana:${nb ?: return newMovieSearchResponse("Error", "error", TvType.Movie) }"
        return if (kind == 2) {
            newTvSeriesSearchResponse(enTitle ?: "No Title", validUrl, TvType.TvSeries) {
                this.posterUrl = imgObjUrl
            }
        } else {
            newMovieSearchResponse(enTitle ?: "No Title", validUrl, TvType.Movie) {
                this.posterUrl = imgObjUrl
            }
        }
    }
}
