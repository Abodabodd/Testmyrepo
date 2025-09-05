package com.cinemana

import com.lagradost.cloudstream3.plugins.BasePlugin
import com.lagradost.cloudstream3.plugins.CloudstreamPlugin

@CloudstreamPlugin
class CinemanaProvider : BasePlugin() {
    override fun load() {
        registerMainAPI(ShabakatyCinemanaProvider())
    }
}    }

    override suspend fun load(url: String): LoadResponse? {
        val videoId = url
        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$videoId"
        val details = app.get(detailsUrl).parsed<CinemanaItem>()

        val title = details.enTitle ?: return null
        val posterUrl = details.imgObjUrl
        val year = details.year?.toIntOrNull()
        val plot = details.enContent
        val scoreInt = details.stars?.let { runCatching { (it.toFloat()/2f*10f).toInt() }.getOrNull() }
        val recommendations = mutableListOf<SearchResponse>()

        return if (details.videoType == 2) {
            val episodesUrl = "$mainUrl/api/android/videoSeason/id/$videoId"
            val episodes = app.get(episodesUrl).parsedSafe<List<CinemanaEpisode>>()?.map {
                newEpisode(it) {
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
                url = video.videoUrl,
            ).let(callback)
        }

        app.get(subtitlesUrl).parsedSafe<CinemanaSubtitleHolder>()?.translations?.forEach { sub ->
            subtitleCallback(SubtitleFile(sub.name ?: "Unknown", sub.file))
        }

        return true
    }

    // ========================
    // Models
    // ========================

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

    private fun CinemanaItem.toSearchResponse(): SearchResponse {
        val validUrl = nb ?: return newMovieSearchResponse("Error","error",TvType.Movie)
        val itemYear = year?.toIntOrNull()
        return if (videoType == 2) {
            newTvSeriesSearchResponse(enTitle ?: "No Title", validUrl, TvType.TvSeries) {
                this.posterUrl = imgObjUrl
                this.year = itemYear
            }
        } else {
            newMovieSearchResponse(enTitle ?: "No Title", validUrl, TvType.Movie) {
                this.posterUrl = imgObjUrl
                this.year = itemYear
            }
        }
    }
}
