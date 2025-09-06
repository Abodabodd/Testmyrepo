package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.newExtractorLink
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

// احتفظ بهذا كما هو، لكننا سنضيف حقل fileFile إليه
// @Serializable
// data class CinemanaItem(
//     val nb: String? = null,
//     @SerialName("en_title") val enTitle: String? = null,
//     val imgObjUrl: String? = null,
//     val year: String? = null,
//     @SerialName("en_content") val enContent: String? = null,
//     val stars: String? = null,
//     val kind: Int? = null,
//     val fileFile: String? = null // إضافة هذا الحقل
// )

class CinemanaProvider : MainAPI() {
    override var name = "Shabakaty Cinemana"
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var lang = "ar"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val items = mutableListOf<HomePageList>()

        // أحدث الأفلام
        val moviesUrl = "$mainUrl/api/android/latestMovies/level/0/itemsPerPage/24/page/$page/"
        val moviesResponse = app.get(moviesUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
        val movies = moviesResponse.map { it.toCinemanaItem().toSearchResponse() }
        items.add(HomePageList("أحدث الأفلام", movies))

        // أحدث المسلسلات
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
        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$url"
        val detailsMap = app.get(detailsUrl).parsedSafe<Map<String, Any>>() ?: return null
        val details = detailsMap.toCinemanaItem() // تأكد من أن toCinemanaItem يمكنها تحليل fileFile

        val title = details.enTitle ?: return null
        val posterUrl = details.imgObjUrl
        val plot = details.enContent
        val year = details.year?.toIntOrNull()
        val scoreValue = details.stars?.toFloatOrNull()?.div(2f) // Score من 0.0 إلى 10.0

        return if (details.kind == 2) {
            newTvSeriesLoadResponse(title, url, TvType.TvSeries, emptyList()) {
                this.posterUrl = posterUrl
                this.plot = plot
                this.year = year
                this.score = scoreValue
            }
        } else {
            // هنا، url الذي يتم تمريره إلى loadLinks هو في الواقع ID (nb)
            newMovieLoadResponse(title, url, TvType.Movie, url) {
                this.posterUrl = posterUrl
                this.plot = plot
                this.year = year
                this.score = scoreValue
            }
        }
    }

    override suspend fun loadLinks(
        data: String, // 'data' هنا هو الـ ID (nb) للفيلم أو المسلسل
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        // الخطوة 1: أعد جلب تفاصيل الفيديو الكاملة (allVideoInfo)
        // لأنها تحتوي على رابط ملف الفيديو وروابط الترجمة مباشرة.
        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$data"
        val detailsMap = app.get(detailsUrl).parsedSafe<Map<String, Any>>()

        // إذا فشل جلب التفاصيل، لا يمكننا الحصول على الروابط
        if (detailsMap == null) {
            // يمكن إضافة سجل خطأ هنا للمساعدة في التصحيح
            // Log.e(name, "Failed to fetch allVideoInfo for ID: $data")
            return false
        }

        // الخطوة 2: استخراج رابط الفيديو
        val videoFileName = detailsMap["fileFile"] as? String
        if (videoFileName != null) {
            // بناء رابط الفيديو الكامل
            // بناءً على نمط روابط الصور والترجمة، غالبًا ما تكون ملفات الفيديو تحت
            // https://cnth2.shabakaty.com/vascin-video-files/
            val fullVideoUrl = "https://cnth2.shabakaty.com/vascin-video-files/$videoFileName"
            newExtractorLink(source = name, name = "Default", url = fullVideoUrl).let(callback)
        } else {
            // Log.e(name, "No video file found in allVideoInfo for ID: $data")
            // يمكن أن تكون هناك حالات لا يوجد فيها ملف فيديو (على سبيل المثال، إذا كان مجرد إدخال معلومات)
            // إذا لم يتم العثور على رابط فيديو، فسيؤدي هذا إلى خطأ "Error loading"
            return false
        }

        // الخطوة 3: استخراج روابط الترجمة
        (detailsMap["translations"] as? List<Map<String, Any>>)?.forEach { sub ->
            val file = sub["file"] as? String // هذا هو الرابط المباشر للملف
            val lang = sub["name"] as? String
            if (file != null && lang != null) {
                subtitleCallback(SubtitleFile(lang, file))
            }
        }

        // أزل أو علّق على الأجزاء القديمة التي كانت تستدعي transcoddedFiles و translationFiles
        // لأننا نستخدم الآن allVideoInfo مباشرة
        /*
        val videosUrl = "$mainUrl/api/android/transcoddedFiles/id/$data"
        val subtitlesUrl = "$mainUrl/api/android/translationFiles/id/$data"

        // روابط الفيديو الأصلية
        app.get(videosUrl).parsedSafe<List<Map<String, Any>>>()?.forEach { videoMap ->
            val videoUrl = videoMap["videoUrl"] as? String ?: return@forEach
            val resolution = videoMap["resolution"] as? String ?: "HD"
            newExtractorLink(source = name, name = resolution, url = videoUrl).let(callback)
        }

        // الترجمة الأصلية
        app.get(subtitlesUrl).parsedSafe<Map<Map<String, Any>>>()?.get("translations")?.let { list ->
            (list as? List<Map<String, Any>>)?.forEach { sub ->
                val file = sub["file"] as? String ?: return@forEach
                val lang = sub["name"] as? String ?: "Unknown"
                subtitleCallback(SubtitleFile(lang, file))
            }
        }
        */

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
        val kind: Int? = null,
        val fileFile: String? = null // *** تأكد من إضافة هذا الحقل هنا ***
    )

    private fun Map<String, Any>.toCinemanaItem(): CinemanaItem {
        return CinemanaItem(
            nb = this["nb"] as? String,
            enTitle = this["en_title"] as? String,
            imgObjUrl = this["imgObjUrl"] as? String ?: this["img"] as? String,
            year = this["year"] as? String,
            enContent = this["en_content"] as? String,
            stars = this["stars"] as? String,
            kind = (this["kind"] as? String)?.toIntOrNull() ?: (this["kind"] as? Int),
            fileFile = this["fileFile"] as? String // *** وتأكد من تحليله هنا ***
        )
    }

    private fun CinemanaItem.toSearchResponse(): SearchResponse {
        val validUrl = nb ?: return newMovieSearchResponse("Error", "error", TvType.Movie)
        return if (kind == 2) {
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
