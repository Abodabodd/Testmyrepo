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

    // واجهة الرئيسية
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

    // البحث
    override suspend fun search(query: String): List<SearchResponse> {
        val moviesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Movies&videoTitle=$query"
        val moviesResponse = app.get(moviesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val movies = moviesResponse.map { it.toCinemanaItem().toSearchResponse() }

        val seriesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Series&videoTitle=$query"
        val seriesResponse = app.get(seriesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val series = seriesResponse.map { it.toCinemanaItem().toSearchResponse() }

        return movies + series
    }

    // تحميل تفاصيل الفيلم / المسلسل
    override suspend fun load(url: String): LoadResponse? {
        val id = url.removePrefix("cinemana:") // إزالة أي prefix
        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$id"
        val detailsMap = app.get(detailsUrl).parsedSafe<Map<String, Any>>() ?: return null
        val details = detailsMap.toCinemanaItem()

        val title = details.enTitle ?: return null
        val posterUrl = details.imgObjUrl ?: details.img
        val plot = details.enContent
        val year = details.year?.toIntOrNull()
        val score = details.stars?.toFloatOrNull()?.let { (it / 2f * 10f).toInt() }

        return if (details.kind == 2) {
            newTvSeriesLoadResponse(title, id, TvType.TvSeries, emptyList()) {
                this.posterUrl = posterUrl
                this.plot = plot
                this.year = year
                this.rating = score
            }
        } else {
            newMovieLoadResponse(title, id, TvType.Movie, id) {
                this.posterUrl = posterUrl
                this.plot = plot
                this.year = year
                this.rating = score
            }
        }
    }

    // تحميل روابط الفيديو والترجمات
    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val id = data.removePrefix("cinemana:")
        val videosUrl = "$mainUrl/api/android/transcoddedFiles/id/$id"
        val subtitlesUrl = "$mainUrl/api/android/translationFiles/id/$id"

        // روابط الفيديو
        val videos = app.get(videosUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        videos.forEach { videoMap ->
            val videoUrl = videoMap["videoUrl"] as? String ?: return@forEach
            val resolution = videoMap["resolution"] as? String ?: "HD"
            newExtractorLink(source = name, name = resolution, url = videoUrl).let(callback)
        }

        // الترجمات
        val subsResponse = app.get(subtitlesUrl).parsedSafe<Map<String, Any>>() ?: emptyMap()
        val translations = subsResponse["translations"] as? List<Map<String, Any>> ?: emptyList()
        translations.forEach { sub ->
            val file = sub["file"] as? String ?: return@forEach
            val lang = sub["name"] as? String ?: "Unknown"
            subtitleCallback(SubtitleFile(lang, file))
        }

        return videos.isNotEmpty()
    }

    // بيانات الفيلم / المسلسل
    @Serializable
    data class CinemanaItem(
        val nb: String? = null,
        @SerialName("en_title") val enTitle: String? = null,
        val imgObjUrl: String? = null,
        val img: String? = null,
        val year: String? = null,
        @SerialName("en_content") val enContent: String? = null,
        val stars: String? = null,
        val kind: Int? = null
    )

    // تحويل Map الى CinemanaItem
    private fun Map<String, Any>.toCinemanaItem(): CinemanaItem {
        return CinemanaItem(
            nb = this["nb"] as? String,
            enTitle = this["en_title"] as? String,
            imgObjUrl = this["imgObjUrl"] as? String,
            img = this["img"] as? String,
            year = this["year"] as? String,
            enContent = this["en_content"] as? String,
            stars = this["stars"] as? String,
            kind = (this["kind"] as? String)?.toIntOrNull() ?: (this["kind"] as? Int)
        )
    }

    // تحويل CinemanaItem الى SearchResponse
    private fun CinemanaItem.toSearchResponse(): SearchResponse {
        val validUrl = nb ?: return newMovieSearchResponse("Error", "error", TvType.Movie)
        return if (kind == 2) {
            newTvSeriesSearchResponse(enTitle ?: "No Title", validUrl, TvType.TvSeries) {
                this.posterUrl = imgObjUrl ?: img
            }
        } else {
            newMovieSearchResponse(enTitle ?: "No Title", validUrl, TvType.Movie) {
                this.posterUrl = imgObjUrl ?: img
            }
        }
    }
}
