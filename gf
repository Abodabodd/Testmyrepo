@file:Suppress("DEPRECATION")

package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.newExtractorLink
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.SerialName

class ShabakatyCinemanaProvider : MainAPI() {
    override var name = "Shabakaty Cinemana"
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var lang = "ar"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val items = mutableListOf<HomePageList>()

        val moviesUrl = "$mainUrl/api/android/latestMovies/level/0/itemsPerPage/24/page/0/"
        val moviesResponse = app.get(moviesUrl).parsedSafe<List<CinemanaItem>>() ?: emptyList()
        items.add(HomePageList("أحدث الأفلام", moviesResponse.map { it.toSearchResponse() }))

        val seriesUrl = "$mainUrl/api/android/latestSeries/level/0/itemsPerPage/24/page/0/"
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

    override suspend fun load(url: String): LoadResponse? {
        val videoId = url
        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$videoId"
        val details = app.get(detailsUrl).parsed<CinemanaItem>()

        val title = details.enTitle ?: return null
        val posterUrl = details.imgObjUrl
        val year = details.year?.toIntOrNull()
        val plot = details.enContent
        val scoreInt = details.stars?.let { (it.toFloat() / 2 * 10).toInt() }
        val recommendations = mutableListOf<SearchResponse>()

        return if (details.videoType == 2) {
            val episodesUrl = "$mainUrl/api/android/videoSeason/id/$videoId"
            val episodes = app.get(episodesUrl).parsedSafe<List<CinemanaEpisode>>()?.map {
                newEpisode(it.nb) {
                    this.name = "الموسم ${it.season} - الحلقة ${it.episodeNummer}"
                    this.episode = it.episodeNummer?.toIntOrNull()
                    this.season = it.season?.toIntOrNull()
                    this.data = it.nb
                }
            }?.sortedWith(compareBy({ it.season }, { it.episode })) ?: emptyList()

            newTvSeriesLoadResponse(title, url, TvType.TvSeries, episodes) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.rating = scoreInt
                this.recommendations = recommendations
                this.contentRating = null
            }
        } else {
            newMovieLoadResponse(title, url, TvType.Movie, url) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.rating = scoreInt
                this.recommendations = recommendations
                this.contentRating = null
            }
        }
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val videoId = data
        val videosUrl = "$mainUrl/api/android/transcoddedFiles/id/$videoId"
        val subtitlesUrl = "$mainUrl/api/android/translationFiles/id/$videoId"

        app.get(videosUrl).parsedSafe<List<CinemanaVideo>>()?.forEach { video ->
            newExtractorLink(
                source = this.name,
                name = video.resolution ?: this.name,
                url = video.videoUrl
            ).let { callback(it) }
        }

        app.get(subtitlesUrl).parsedSafe<CinemanaSubtitleHolder>()?.translations?.forEach { sub ->
            val lang = sub.name ?: "Unknown"
            subtitleCallback(SubtitleFile(lang, sub.file))
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
    ) {
        fun toSearchResponse(): SearchResponse {
            val validUrl = nb ?: return this@ShabakatyCinemanaProvider.newMovieSearchResponse(
                title = "Error",
                url = "error",
                type = TvType.Movie
            )

            return if (this.videoType == 2) {
                this@ShabakatyCinemanaProvider.newTvSeriesSearchResponse(
                    title = enTitle ?: "No Title",
                    url = validUrl,
                    type = TvType.TvSeries
                ) {
                    this.posterUrl = imgObjUrl
                    this.year = this@CinemanaItem.year?.toIntOrNull()
                }
            } else {
                this@ShabakatyCinemanaProvider.newMovieSearchResponse(
                    title = enTitle ?: "No Title",
                    url = validUrl,
                    type = TvType.Movie
                ) {
                    this.posterUrl = imgObjUrl
                    this.year = this@CinemanaItem.year?.toIntOrNull()
                }
            }
        }
    }

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
}    override suspend fun search(query: String): List<SearchResponse> {
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
        val year = details.year?.toIntOrNull()
        val plot = details.enContent
        val scoreInt = details.stars?.let { (it.toFloat() / 2 * 10).toInt() }
        val recommendations = mutableListOf<SearchResponse>()

        return if (details.videoType == 2) {
            val episodesUrl = "$mainUrl/api/android/videoSeason/id/$videoId"
            val episodes = app.get(episodesUrl).parsedSafe<List<CinemanaEpisode>>()?.map {
                newEpisode(it.nb) {
                    this.name = "الموسم ${it.season} - الحلقة ${it.episodeNummer}"
                    this.episode = it.episodeNummer?.toIntOrNull()
                    this.season = it.season?.toIntOrNull()
                    this.data = it.nb
                }
            }?.sortedWith(compareBy({ it.season }, { it.episode })) ?: emptyList()

            newTvSeriesLoadResponse(title, url, TvType.TvSeries, episodes) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.rating = scoreInt
                this.recommendations = recommendations
                this.contentRating = null
            }
        } else {
            newMovieLoadResponse(title, url, TvType.Movie, url) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.rating = scoreInt
                this.recommendations = recommendations
                this.contentRating = null
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
        val subtitlesUrl = "$mainUrl/api/android/translationFiles/id/$data"

        app.get(videosUrl).parsedSafe<List<CinemanaVideo>>()?.forEach { video ->
            newExtractorLink(
                source = this.name,
                name = video.resolution ?: this.name,
                url = video.videoUrl,
            ).let { callback(it) }
        }

        app.get(subtitlesUrl).parsedSafe<CinemanaSubtitleHolder>()?.translations?.forEach { sub ->
            val lang = sub.name ?: "Unknown"
            subtitleCallback(SubtitleFile(lang, sub.file))
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
    ) {
        fun toSearchResponse(): SearchResponse {
            val validUrl = nb ?: return this@ShabakatyCinemanaProvider.newMovieSearchResponse(
                "Error", "error", this@ShabakatyCinemanaProvider.name, TvType.Movie
            )

            return if (this.videoType == 2) {
                this@ShabakatyCinemanaProvider.newTvSeriesSearchResponse(enTitle ?: "No Title", validUrl, TvType.TvSeries) {
                    this.posterUrl = imgObjUrl
                    this.year = this@CinemanaItem.year?.toIntOrNull()
                }
            } else {
                this@ShabakatyCinemanaProvider.newMovieSearchResponse(enTitle ?: "No Title", validUrl, TvType.Movie) {
                    this.posterUrl = imgObjUrl
                    this.year = this@CinemanaItem.year?.toIntOrNull()
                }
            }
        }
    }

    @Serializable
    data class CinemanaEpisode(val nb: String, val episodeNummer: String?, val season: String?)
    @Serializable
    data class CinemanaVideo(val videoUrl: String, val resolution: String?)
    @Serializable
    data class CinemanaSubtitleHolder(val translations: List<CinemanaSubtitleFile>?)
    @Serializable
    data class CinemanaSubtitleFile(val file: String, val name: String?)
}
