package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.newExtractorLink
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

class CinemanaProvider : MainAPI() {
    override var name = "Shabakaty Cinemana"
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var lang = "ar"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    // -----------------------
    // Main page (latest / series / popular)
    // -----------------------
    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val items = mutableListOf<HomePageList>()

        // أحدث الأفلام
        val moviesUrl = "$mainUrl/api/android/latestMovies/level/0/itemsPerPage/24/page/$page/"
        val moviesResponse = app.get(moviesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val movies = moviesResponse.mapNotNull { it.toCinemanaItem().toSearchResponse() }
        items.add(HomePageList("أحدث الأفلام", movies))

        // أحدث المسلسلات
        val seriesUrl = "$mainUrl/api/android/latestSeries/level/0/itemsPerPage/24/page/$page/"
        val seriesResponse = app.get(seriesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val series = seriesResponse.mapNotNull { it.toCinemanaItem().toSearchResponse() }
        items.add(HomePageList("أحدث المسلسلات", series))

        // الأكثر مشاهدة (popular)
        val popularUrl = "$mainUrl/api/android/mostViewed/level/0/itemsPerPage/24/page/$page/"
        val popularResponse = app.get(popularUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val popular = popularResponse.mapNotNull { it.toCinemanaItem().toSearchResponse() }
        items.add(HomePageList("الأكثر مشاهدة", popular))

        return newHomePageResponse(items)
    }

    // -----------------------
    // Search
    // -----------------------
    override suspend fun search(query: String): List<SearchResponse> {
        val moviesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Movies&videoTitle=${query.encodeURL()}"
        val moviesResponse = app.get(moviesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val movies = moviesResponse.mapNotNull { it.toCinemanaItem().toSearchResponse() }

        val seriesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Series&videoTitle=${query.encodeURL()}"
        val seriesResponse = app.get(seriesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val series = seriesResponse.mapNotNull { it.toCinemanaItem().toSearchResponse() }

        return movies + series
    }

    // -----------------------
    // Load (تفاصيل الفيديو/المسلسل)
    // -----------------------
    override suspend fun load(url: String): LoadResponse? {
        val id = extractId(url)
        if (id.isBlank()) return null

        // اطلب التفاصيل (مع showInfo إذا أردت)
        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$id?showInfo=true"
        val detailsMap = app.get(detailsUrl).parsedSafe<Map<String, Any>>() ?: return null
        val details = detailsMap.toCinemanaItem()

        val title = details.enTitle ?: details.arTitle ?: "بدون عنوان"
        val posterUrl = details.imgObjUrl ?: details.img ?: null
        val plot = details.enContent ?: details.arContent
        val year = details.year?.toIntOrNull()
        val score = details.stars?.toFloatOrNull()?.let { (it / 2f * 10f).toInt() }

        return if (details.kind == 2) {
            // لو هو مسلسل، حاول جلب الحلقات إن كانت متوفرة في response (ملف فيديو موسم)
            val episodes = mutableListOf<Episode>()
            // بعض API يعيد موسم/حلقة في مكان آخر - هنا تعامل بسيط: لا حلقات افتراضياً
            newTvSeriesLoadResponse(title, "cinemana:$id", TvType.TvSeries, episodes) {
                this.posterUrl = posterUrl
                this.plot = plot
                this.year = year
                this.rating = score
            }
        } else {
            newMovieLoadResponse(title, "cinemana:$id", TvType.Movie, "cinemana:$id") {
                this.posterUrl = posterUrl
                this.plot = plot
                this.year = year
                this.rating = score
            }
        }
    }

    // -----------------------
    // loadLinks: يبني روابط التشغيل والترجمات
    // -----------------------
    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val id = extractId(data)
        if (id.isBlank()) return false

        val videosUrl = "$mainUrl/api/android/transcoddedFiles/id/$id"
        val subtitlesUrl = "$mainUrl/api/android/translationFiles/id/$id"

        // روابط الفيديو
        app.get(videosUrl).parsedSafe<List<Map<String, Any>>>()?.forEach { videoMap ->
            // بعض الاستجابات قد تحتوي مفاتيح مختلفة
            val videoUrl = videoMap.getString("video", "videoUrl", "file") ?: return@forEach
            val resolution = videoMap.getString("resolution", "name") ?: "Unknown"
            newExtractorLink(source = name, name = resolution, url = videoUrl).let(callback)
        }

        // الترجمات
        app.get(subtitlesUrl).parsedSafe<Map<String, Any>>()?.get("translations")?.let { list ->
            (list as? List<Map<String, Any>>)?.forEach { sub ->
                val file = sub["file"] as? String ?: return@forEach
                val lang = sub["name"] as? String ?: sub["type"] as? String ?: "Unknown"
                subtitleCallback(SubtitleFile(lang, file))
            }
        }

        return true
    }

    // -----------------------
    // مساعدات لتحويل الـ Map ولإستخراج الحقول
    // -----------------------
    @Serializable
    data class CinemanaItem(
        val nb: String? = null,
        @SerialName("en_title") val enTitle: String? = null,
        @SerialName("ar_title") val arTitle: String? = null,
        val imgObjUrl: String? = null,
        val img: String? = null,
        val year: String? = null,
        @SerialName("en_content") val enContent: String? = null,
        @SerialName("ar_content") val arContent: String? = null,
        val stars: String? = null,
        val kind: Int? = null,
        val fileFile: String? = null
    )

    // helper: القراءة من Map مع عدة مفاتيح محتملة
    private fun Map<String, Any>.getString(vararg keys: String): String? {
        for (k in keys) {
            if (this.containsKey(k)) {
                val v = this[k] ?: continue
                return when (v) {
                    is String -> v
                    is Number -> v.toString()
                    else -> v.toString()
                }
            }
        }
        return null
    }

    private fun Map<String, Any>.toCinemanaItem(): CinemanaItem {
        // بعض ال endpoints قد ترجع الحقول تحت أسماء مختلفة، لذا نفحص عدة مفاتيح
        val nb = getString("nb", "id", "videoId")
        val enTitle = getString("en_title", "title", "video_title", "enTitle")
        val arTitle = getString("ar_title", "title_ar")
        val imgObjUrl = getString("imgObjUrl", "imgObj", "img", "imgMediumThumbObjUrl")
        val img = getString("img", "imgObjUrl", "imgThumbObjUrl")
        val year = getString("year", "mDate")
        val enContent = getString("en_content", "description", "enContent")
        val arContent = getString("ar_content")
        val stars = getString("stars", "rate", "filmRating", "seriesRating")
        val kindStr = getString("kind", "videoType")
        val kind = kindStr?.toIntOrNull()
        val fileFile = getString("fileFile", "file", "video")

        return CinemanaItem(
            nb = nb,
            enTitle = enTitle,
            arTitle = arTitle,
            imgObjUrl = imgObjUrl,
            img = img,
            year = year,
            enContent = enContent,
            arContent = arContent,
            stars = stars,
            kind = kind,
            fileFile = fileFile
        )
    }

    private fun CinemanaItem.toSearchResponse(): SearchResponse? {
        val id = this.nb ?: return null
        // *** مهم جداً: ضع URL القيمة كـ ID فقط (سيتم استخراجها لاحقاً في load/loadLinks) ***
        val storedUrl = id.toString()
        return if (this.kind == 2) {
            newTvSeriesSearchResponse(this.enTitle ?: this.arTitle ?: "No Title", storedUrl, TvType.TvSeries) {
                this.posterUrl = this.imgObjUrl ?: this.img
            }
        } else {
            newMovieSearchResponse(this.enTitle ?: this.arTitle ?: "No Title", storedUrl, TvType.Movie) {
                this.posterUrl = this.imgObjUrl ?: this.img
            }
        }
    }

    // -----------------------
    // استخراج ID مرن من أي شكل للـ url
    // يقبل: "799" أو "cinemana:799" أو "https://cinemana.../799" أو "799?showInfo=true"
    // -----------------------
    private fun extractId(raw: String?): String {
        if (raw.isNullOrBlank()) return ""
        var id = raw.trim()

        // لو فيه بادئة خاصة نزيلها
        if (id.contains("cinemana:")) {
            id = id.substringAfter("cinemana:")
        }

        // لو هو رابط كامل خذ آخر جزء بعد '/'
        if (id.startsWith("http://") || id.startsWith("https://")) {
            id = id.substringAfterLast("/")
        }

        // decode percent-encoding (e.g. %3F -> ?)
        try {
            id = URLDecoder.decode(id, StandardCharsets.UTF_8.name())
        } catch (e: Exception) {
            // ignore
        }

        // أزل query params أو fragments
        id = id.substringBefore("?").substringBefore("#").substringBefore("%3F")

        // trim spaces
        id = id.trim()

        return id
    }
}
