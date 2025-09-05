package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.newExtractorLink
import com.lagradost.cloudstream3.utils.toJson
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class CinemanaProvider : MainAPI() {
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var name = "Cinemana"
    override var lang = "ar"
    override val hasMainPage = true
    override val hasQuickSearch = true
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    override val mainPage = mainPageOf(
        "$mainUrl/api/android/latestMovies/level/0/itemsPerPage/24/page/0/" to "أحدث الأفلام",
        "$mainUrl/api/android/latestSeries/level/0/itemsPerPage/24/page/0/" to "أحدث المسلسلات"
    )

    // -------------------------
    // Main page
    // -------------------------
    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val url = request.data
        val list = app.get(url).parsedSafe<List<CinemanaItem>>()?.mapNotNull { item ->
            item.toSearchResponse()
        } ?: emptyList()

        return newHomePageResponse(listOf(HomePageList(request.name, list)), hasNext = false)
    }

    // -------------------------
    // Search
    // -------------------------
    override suspend fun search(query: String): List<SearchResponse> {
        val moviesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Movies&videoTitle=$query"
        val seriesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Series&videoTitle=$query"

        val movies = app.get(moviesUrl).parsedSafe<List<CinemanaItem>>()?.mapNotNull { it.toSearchResponse() } ?: emptyList()
        val series = app.get(seriesUrl).parsedSafe<List<CinemanaItem>>()?.mapNotNull { it.toSearchResponse() } ?: emptyList()

        return movies + series
    }

    // -------------------------
    // Load details (movie / series)
    // -------------------------
    override suspend fun load(url: String): LoadResponse? {
        // الـ URL هنا نمرره كـ id (nb) حسب تصميمنا — أنت تستخدم url = id عند إنشاء search responses
        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$url"
        val details = app.get(detailsUrl).parsedSafe<CinemanaItem>() ?: return null

        val title = details.enTitle ?: details.arTitle ?: "Unknown"
        val posterUrl = details.imgObjUrl ?: details.poster
        val type = when {
            // بعض الـ API تستخدم field "videoType", بعضهم "kind" -> نحاول الاثنين
            details.videoType?.toIntOrNull() == 2 -> TvType.TvSeries
            details.kind?.toIntOrNull() == 2 -> TvType.TvSeries
            else -> TvType.Movie
        }

        return if (type == TvType.TvSeries) {
            // استرجاع حلقات من endpoint المعروف
            val episodes = app.get("$mainUrl/api/android/videoSeason/id/$url").parsedSafe<List<CinemanaEpisode>>()?.map { ep ->
                newEpisode(ep.nb) {
                    this.name = "الموسم ${ep.season ?: "?"} - الحلقة ${ep.episodeNummer ?: "?"}"
                    this.episode = ep.episodeNummer?.toIntOrNull()
                    this.season = ep.season?.toIntOrNull()
                    this.data = ep.nb
                }
            }?.sortedWith(compareBy({ it.season }, { it.episode })) ?: emptyList()

            newTvSeriesLoadResponse(title, url, type, episodes) {
                this.posterUrl = posterUrl
                this.plot = details.enContent ?: details.arContent
            }
        } else {
            newMovieLoadResponse(title, url, type, details.fileFile ?: url) {
                this.posterUrl = posterUrl
                this.plot = details.enContent ?: details.arContent
            }
        }
    }

    // -------------------------
    // Load links (video sources + subtitles)
    // -------------------------
    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        // data هو id (nb) أو القيمة التي وضعناها في new*SearchResponse كـ url
        val videosUrl = "$mainUrl/api/android/transcoddedFiles/id/$data"
        val videos = app.get(videosUrl).parsedSafe<List<CinemanaVideo>>() ?: emptyList()

        videos.forEach { v ->
            // newExtractorLink هو الطريقة المريحة
            newExtractorLink(
                source = name,
                name = v.resolution ?: name,
                url = v.videoUrl
            ).let { callback(it) }
        }

        // ترجمات
        val subsUrl = "$mainUrl/api/android/translationFiles/id/$data"
        val subsHolder = app.get(subsUrl).parsedSafe<CinemanaSubtitleHolder>()
        subsHolder?.translations?.forEach { sub ->
            subtitleCallback(SubtitleFile(sub.name ?: "Unknown", sub.file))
        }

        return true
    }

    // -------------------------
    // Mapper (helper) — يستعمل newMovieSearchResponse / newTvSeriesSearchResponse
    // -------------------------
    private fun CinemanaItem.toSearchResponse(): SearchResponse? {
        val id = this.nb ?: return null
        // نحتفظ بالـ id كـ url لأنه الأسهل — cloudstream سيعطيه لاحقًا لـ load()
        return if ((this.videoType?.toIntOrNull() ?: this.kind?.toIntOrNull() ?: 1) == 2) {
            newTvSeriesSearchResponse(this.enTitle ?: this.arTitle ?: "Unknown", id, TvType.TvSeries) {
                this.posterUrl = this@toSearchResponse.imgObjUrl ?: this@toSearchResponse.poster
            }
        } else {
            newMovieSearchResponse(this.enTitle ?: this.arTitle ?: "Unknown", id, TvType.Movie) {
                this.posterUrl = this@toSearchResponse.imgObjUrl ?: this@toSearchResponse.poster
            }
        }
    }
}

// -------------------------
// DTOs (top-level, @Serializable)
// -------------------------
@Serializable
data class CinemanaItem(
    val nb: String? = null,
    @SerialName("en_title") val enTitle: String? = null,
    @SerialName("ar_title") val arTitle: String? = null,
    val stars: String? = null,
    @SerialName("en_content") val enContent: String? = null,
    @SerialName("ar_content") val arContent: String? = null,
    val year: String? = null,
    val kind: String? = null,                 // sometimes used instead of videoType
    val videoType: String? = null,            // some endpoints may return this
    @SerialName("imgObjUrl") val imgObjUrl: String? = null,
    val poster: String? = null,
    val fileFile: String? = null,             // ملف الفيديو/اسم الملف كما ظهر في JSON
    val translations: List<CinemanaSubtitleFile>? = null,
    val episodeNummer: String? = null,
    val season: String? = null
)

@Serializable
data class CinemanaEpisode(
    val nb: String,
    val episodeNummer: String? = null,
    val season: String? = null
)

@Serializable
data class CinemanaVideo(
    val videoUrl: String,
    val resolution: String? = null
)

@Serializable
data class CinemanaSubtitleHolder(
    val translations: List<CinemanaSubtitleFile>? = null
)

@Serializable
data class CinemanaSubtitleFile(
    val file: String,
    val name: String? = null
)
