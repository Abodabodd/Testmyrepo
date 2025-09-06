package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.ExtractorLink
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

        val moviesUrl = "$mainUrl/api/android/latestMovies/level/0/itemsPerPage/24/page/$page/"
        val moviesResponse = app.get(moviesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val movies = moviesResponse.map { it.toCinemanaItem().toSearchResponse() }
        items.add(HomePageList("أحدث الأفلام", movies))

        val seriesUrl = "$mainUrl/api/android/latestSeries/level/0/itemsPerPage/24/page/$page/"
        val seriesResponse = app.get(seriesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val series = seriesResponse.map { it.toCinemanaItem().toSearchResponse() }
        items.add(HomePageList("أحدث المسلسلات", series))

        return newHomePageResponse(items)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val moviesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Movies&videoTitle=$query"
        val moviesResponse = app.get(moviesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val movies = moviesResponse.map { it.toCinemanaItem().toSearchResponse() }

        val seriesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Series&videoTitle=$query"
        val seriesResponse = app.get(seriesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val series = seriesResponse.map { it.toCinemanaItem().toSearchResponse() }

        return movies + series
    }

    override suspend fun load(url: String): LoadResponse? {
        val id = url.removePrefix("cinemana:")
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
        val id = data.removePrefix("cinemana:")
        val videosUrl = "$mainUrl/api/android/transcoddedFiles/id/$id"
        val subtitlesUrl = "$mainUrl/api/android/translationFiles/id/$id"

        val videos = app.get(videosUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        videos.forEach { videoMap ->
            val videoUrl = videoMap["videoUrl"] as? String ?: return@forEach
            val resolution = videoMap["resolution"] as? String ?: "HD"
            callback(newExtractorLink(name = resolution, url = videoUrl, source = name))
        }

        val subsMap = app.get(subtitlesUrl).parsedSafe<Map<String, Any>>() ?: emptyMap()
        val translations = subsMap["translations"] as? List<Map<String, Any>> ?: emptyList()
        translations.forEach { sub ->
            val file = sub["file"] as? String ?: return@forEach
            val lang = sub["name"] as? String ?: "Unknown"
            subtitleCallback(SubtitleFile(lang, file))
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
            imgObjUrl = this["imgObjUrl"] as? String,
            year = this["year"] as? String,
            enContent = this["en_content"] as? String,
            stars = this["stars"] as? String,
            kind = (this["kind"] as? String)?.toIntOrNull() ?: (this["kind"] as? Int)
        )
    }

    private fun CinemanaItem.toSearchResponse(): SearchResponse {
        val validUrl = "cinemana:${nb ?: return newMovieSearchResponse("Error", "error", TvType.Movie)}"
        return if (kind == 2) {
            newTvSeriesSearchResponse(enTitle ?: "No Title", validUrl, TvType.TvSeries) {
                posterUrl = imgObjUrl
            }
        } else {
            newMovieSearchResponse(enTitle ?: "No Title", validUrl, TvType.Movie) {
                posterUrl = imgObjUrl
            }
        }
    }
}
