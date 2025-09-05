package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

class Cinemana : MainAPI() {
    override var name = "Cinemana"
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var lang = "ar"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)
    override val hasMainPage = true
    override val hasDownloadSupport = false

    override val mainPage = mainPageOf(
        "$mainUrl/api/android/latestMovies/level/0/itemsPerPage/24/page/0/" to "أحدث الأفلام",
        "$mainUrl/api/android/latestSeries/level/0/itemsPerPage/24/page/0/" to "أحدث المسلسلات"
    )

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val url = request.data
        val response = app.get(url).parsedSafe<List<CinemanaItem>>() ?: emptyList()
        val list = response.map { it.toSearchResponse() }
        return newHomePageResponse(listOf(HomePageList(request.name, list)))
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val moviesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Movies&videoTitle=$query"
        val seriesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Series&videoTitle=$query"

        val movies = app.get(moviesUrl).parsedSafe<List<CinemanaItem>>()?.map { it.toSearchResponse() } ?: emptyList()
        val series = app.get(seriesUrl).parsedSafe<List<CinemanaItem>>()?.map { it.toSearchResponse() } ?: emptyList()

        return movies + series
    }

    override suspend fun load(url: String): LoadResponse? {
        val details = app.get("$mainUrl/api/android/allVideoInfo/id/$url").parsedSafe<CinemanaItem>() ?: return null
        val title = details.enTitle ?: "Unknown"
        val poster = details.imgObjUrl
        val type = if (details.videoType == 2) TvType.TvSeries else TvType.Movie

        return if (type == TvType.TvSeries) {
            val episodesJson = app.get("$mainUrl/api/android/videoSeason/id/$url").toString()
            val episodesList = parseJson<List<CinemanaEpisode>>(episodesJson).map {
                newEpisode(it.nb) {
                    this.name = "الموسم ${it.season} - الحلقة ${it.episodeNummer}"
                    this.episode = it.episodeNummer?.toIntOrNull()
                    this.season = it.season?.toIntOrNull()
                    this.data = it.nb
                }
            }
            newTvSeriesLoadResponse(title, url, type, episodesList) {
                this.posterUrl = poster
            }
        } else {
            newMovieLoadResponse(title, url, type, url) {
                this.posterUrl = poster
            }
        }
    }

    override suspend fun loadLinks(data: String, isCasting: Boolean, subtitleCallback: (SubtitleFile) -> Unit, callback: (ExtractorLink) -> Unit): Boolean {
        val videos = app.get("$mainUrl/api/android/transcoddedFiles/id/$data").parsedSafe<List<CinemanaVideo>>() ?: return false
        videos.forEach {
            callback(newExtractorLink(name, it.resolution ?: "Default", it.videoUrl))
        }
        return true
    }

    // =========================
    // DTOs
    // =========================
    @Serializable
    data class CinemanaItem(
        val nb: String? = null,
        @SerialName("en_title") val enTitle: String? = null,
        val imgObjUrl: String? = null,
        val videoType: Int? = null,
        val year: String? = null,
        @SerialName("en_content") val enContent: String? = null,
        val stars: String? = null
    )

    @Serializable
    data class CinemanaEpisode(
        val nb: String,
        val episodeNummer: String?,
        val season: String?
    )

    @Serializable
    data class CinemanaVideo(
        val videoUrl: String,
        val resolution: String?
    )

    // =========================
    // Mappers
    // =========================
    private fun CinemanaItem.toSearchResponse(): SearchResponse {
        val id = nb ?: return newMovieSearchResponse("Unknown", "error", TvType.Movie)
        val type = if (videoType == 2) TvType.TvSeries else TvType.Movie
        return if (type == TvType.TvSeries) {
            newTvSeriesSearchResponse(enTitle ?: "Unknown", id, type) {
                this.posterUrl = imgObjUrl
            }
        } else {
            newMovieSearchResponse(enTitle ?: "Unknown", id, type) {
                this.posterUrl = imgObjUrl
            }
        }
    }
}
