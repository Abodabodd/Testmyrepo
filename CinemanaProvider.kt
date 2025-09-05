package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

class CinemanaProvider : MainAPI() {
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var name = "Cinemana"
    override val hasMainPage = true
    override var lang = "ar"
    override val hasDownloadSupport = true
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    override val mainPage = mainPageOf(
        "$mainUrl/api/android/latestMovies/level/0/itemsPerPage/24/page/0/" to "أحدث الأفلام",
        "$mainUrl/api/android/latestSeries/level/0/itemsPerPage/24/page/0/" to "أحدث المسلسلات"
    )

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val items = mutableListOf<HomePageList>()

        val moviesResponse = app.get(request.data).parsedSafe<List<CinemanaItem>>() ?: emptyList()
        items.add(HomePageList(request.name, moviesResponse.map { it.toSearchResponse() }))

        return newHomePageResponse(items)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val moviesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Movies&videoTitle=$query"
        val movies = app.get(moviesUrl).parsedSafe<List<CinemanaItem>>()?.map { it.toSearchResponse() } ?: emptyList()

        val seriesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Series&videoTitle=$query"
        val series = app.get(seriesUrl).parsedSafe<List<CinemanaItem>>()?.map { it.toSearchResponse() } ?: emptyList()

        return movies + series
    }

    override suspend fun load(url: String): LoadResponse? {
        val videoId = url
        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$videoId"
        val details = app.get(detailsUrl).parsed<CinemanaItem>()

        val title = details.enTitle ?: return null
        val posterUrl = details.imgObjUrl
        val plot = details.enContent
        val isSeries = details.videoType == 2

        return if (isSeries) {
            newTvSeriesLoadResponse(title, url, TvType.TvSeries, emptyList()) {
                this.posterUrl = posterUrl
                this.plot = plot
            }
        } else {
            newMovieLoadResponse(title, url, TvType.Movie, url) {
                this.posterUrl = posterUrl
                this.plot = plot
            }
        }
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val videosUrl = "$mainUrl/api/android/transcoddedFiles/id/$data"
        app.get(videosUrl).parsedSafe<List<CinemanaVideo>>()?.forEach { video ->
            newExtractorLink(
                source = this.name,
                name = video.resolution ?: this.name,
                url = video.videoUrl
            ).let(callback)
        }

        val subtitlesUrl = "$mainUrl/api/android/translationFiles/id/$data"
        app.get(subtitlesUrl).parsedSafe<CinemanaSubtitleHolder>()?.translations?.forEach { sub ->
            subtitleCallback(SubtitleFile(sub.name ?: "Unknown", sub.file))
        }

        return true
    }

    // ========================
    // DTOs
    // ========================
    @Serializable
    data class CinemanaItem(
        @SerialName("en_title") val enTitle: String? = null,
        val imgObjUrl: String? = null,
        @SerialName("en_content") val enContent: String? = null,
        val videoType: Int? = null,
        val nb: String? = null
    )

    @Serializable
    data class CinemanaVideo(
        val videoUrl: String,
        val resolution: String?
    )

    @Serializable
    data class CinemanaSubtitleHolder(
        val translations: List<CinemanaSubtitleFile>?
    )

    @Serializable
    data class CinemanaSubtitleFile(
        val file: String,
        val name: String?
    )

    private fun CinemanaItem.toSearchResponse(): SearchResponse {
        val validUrl = nb ?: return newMovieSearchResponse("Error", "error", TvType.Movie)
        return if (videoType == 2) {
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
