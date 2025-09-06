package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.newExtractorLink
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

class CinemanaProvider : MainAPI() {
    override var name = "Cinemana"
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var lang = "ar"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val items = mutableListOf<HomePageList>()
        val moviesUrl = "$mainUrl/api/android/latestMovies/level/0/itemsPerPage/24/page/$page/"
        val moviesResponse = app.get(moviesUrl).parsedSafe<List<CinemanaItem>>() ?: emptyList()
        items.add(HomePageList("أحدث الأفلام", moviesResponse.map { it.toSearchResponse() }))

        val seriesUrl = "$mainUrl/api/android/latestSeries/level/0/itemsPerPage/24/page/$page/"
        val seriesResponse = app.get(seriesUrl).parsedSafe<List<CinemanaItem>>() ?: emptyList()
        items.add(HomePageList("أحدث المسلسلات", seriesResponse.map { it.toSearchResponse() }))

        return newHomePageResponse(items)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val moviesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Movies&videoTitle=$query"
        val movies = app.get(moviesUrl).parsedSafe<List<CinemanaItem>>()?.map { it.toSearchResponse() } ?: emptyList()

        val seriesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Series&videoTitle=$query"
        val series = app.get(seriesUrl).parsedSafe<List<CinemanaItem>>()?.map { it.toSearchResponse() } ?: emptyList()

        return movies + series
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
                source = name,
                name = video.resolution ?: name,
                url = video.videoUrl
            ).let(callback)
        }

        val subtitlesUrl = "$mainUrl/api/android/translationFiles/id/$data"
        app.get(subtitlesUrl).parsedSafe<CinemanaSubtitleHolder>()?.translations?.forEach { sub ->
            subtitleCallback(SubtitleFile(sub.name ?: "Unknown", sub.file))
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
        val videoType: Int? = null
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
        val url = nb ?: return newMovieSearchResponse("Unknown", "error", TvType.Movie)
        return if (videoType == 2) {
            newTvSeriesSearchResponse(enTitle ?: "No Title", url, TvType.TvSeries) {
                this.posterUrl = imgObjUrl
            }
        } else {
            newMovieSearchResponse(enTitle ?: "No Title", url, TvType.Movie) {
                this.posterUrl = imgObjUrl
            }
        }
    }
}
