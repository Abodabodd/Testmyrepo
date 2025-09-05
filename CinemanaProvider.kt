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
            val episodes = app.get("$mainUrl/api/android/videoSeason/id/$url").parsedSafe<List<CinemanaEpisode>>() ?: emptyList()
            val eps = episodes.map { ep ->
                newEpisode(ep.nb) {
                    this.name = "الموسم ${ep.season} - الحلقة ${ep.episodeNummer}"
                    this.episode = ep.episodeNummer?.toIntOrNull()
                    this.season = ep.season?.toIntOrNull()
                    this.data = ep.nb
                }
            }.sortedWith(compareBy({ it.season }, { it.episode }))

            newTvSeriesLoadResponse(title, url, type, eps) {
                this.posterUrl = poster
            }
        } else {
            newMovieLoadResponse(title, url, type, url) {
                this.posterUrl = poster
            }
        }
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val videos = app.get("$mainUrl/api/android/transcoddedFiles/id/$data").parsedSafe<List<CinemanaVideo>>() ?: return false
        videos.forEach { video ->
            callback(
                newExtractorLink(
                    source = name,
                    name = video.resolution ?: "Default",
                    url = video.videoUrl
                )
            )
        }

        val subs = app.get("$mainUrl/api/android/translationFiles/id/$data").parsedSafe<CinemanaSubtitleHolder>()
        subs?.translations?.forEach { sub ->
            subtitleCallback(SubtitleFile(sub.name ?: "Unknown", sub.file))
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

    @Serializable
    data class CinemanaSubtitleHolder(
        val translations: List<CinemanaSubtitleFile>?
    )

    @Serializable
    data class CinemanaSubtitleFile(
        val file: String,
        val name: String?
    )

    // =========================
    // Mapper
    // =========================
    private fun CinemanaItem.toSearchResponse(): SearchResponse {
        val id = nb ?: return newMovieSearchResponse("Unknown", "error", TvType.Movie)
        return if (videoType == 2) {
            newTvSeriesSearchResponse(enTitle ?: "Unknown", id, TvType.TvSeries) {
                this.posterUrl = imgObjUrl
            }
        } else {
            newMovieSearchResponse(enTitle ?: "Unknown", id, TvType.Movie) {
                this.posterUrl = imgObjUrl
            }
        }
    }
}
