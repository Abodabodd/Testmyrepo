// حفظ الملف باسم: ExactYoutubeProvider.kt
package com.my.youtubeprovider // يمكنك تغيير هذا

import com.lagradost.cloudstream3.plugins.CloudstreamPlugin
import com.lagradost.cloudstream3.plugins.Plugin
import android.content.Context
import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*
import com.lagradost.cloudstream3.utils.AppUtils.parseJson
import com.lagradost.cloudstream3.utils.AppUtils.toJson
import com.fasterxml.jackson.annotation.JsonProperty
import kotlin.math.min

@CloudstreamPlugin
class ExactYoutubeProviderPlugin : Plugin() {
    override fun load(context: Context) {
        registerMainAPI(ExactYoutubeProvider())
    }
}

// =================================================================================
// هياكل البيانات (Data Classes) اللازمة لتحليل JSON المعقد
// =================================================================================

data class YtInitialData(
    @JsonProperty("contents") val contents: Map<String, Any>? = null,
    @JsonProperty("header") val header: Map<String, Any>? = null
)

data class YtCfgSet(
    @JsonProperty("INNERTUBE_API_KEY") val apiKey: String? = null,
    @JsonProperty("INNERTUBE_CLIENT_VERSION") val clientVersion: String? = null,
    @JsonProperty("VISITOR_DATA") val visitorData: String? = null
)

data class ContinuationPayload(
    val token: String,
    val apiKey: String?,
    val clientVersion: String?,
    val visitorData: String?
)

data class OembedResponse(
    @JsonProperty("title") val title: String? = null
)

class ExactYoutubeProvider : MainAPI() {
    override var mainUrl = "https://www.youtube.com"
    override var name = "My Exact YouTube"
    override val supportedTypes = setOf(TvType.Others) // Use 'Others' for flexibility
    override var lang = "ar"
    override val hasMainPage = true

    private val mUrl = "https://m.youtube.com"
    private val webUrl = "https://www.youtube.com"

    // =================================================================================
    // دوال مساعدة عامة مستوحاة من أكوادك
    // =================================================================================

    // استخراج ytInitialData
    private fun extractYtInitialData(html: String): Map<String, Any>? {
        val patterns = listOf(
            """var ytInitialData\s*=\s*(\{.*?\});""",
            """window\[['"]ytInitialData['"]\]\s*=\s*(\{.*?\});"""
        )
        for (pattern in patterns) {
            val match = Regex(pattern, RegexOption.DOT_MATCHES_ALL).find(html)
            if (match != null) {
                try {
                    return parseJson(match.groupValues[1])
                } catch (e: Exception) {
                    continue
                }
            }
        }
        return null
    }

    // استخراج ytcfg.set
    private fun extractYtCfg(html: String): YtCfgSet? {
        val match = Regex("""ytcfg\.set\(\s*(\{.*?\})\s*\);""", RegexOption.DOT_MATCHES_ALL).find(html)
        return match?.groupValues?.get(1)?.let { parseJson<YtCfgSet>(it) }
    }

    // دالة مرنة لاستخراج العناوين من مختلف هياكل JSON
    private fun extractTitle(obj: Map<String, Any>?): String? {
        if (obj == null) return null
        val candidates = listOf(
            "title", "headline", "primaryText", "label", "simpleText", "text", "name"
        )
        for (key in candidates) {
            val field = obj[key]
            if (field is String) return field
            if (field is Map<*, *>) {
                val simpleText = (field as Map<String, Any>).get("simpleText") as? String
                if (simpleText != null) return simpleText
                val runs = field.get("runs") as? List<Map<String, Any>>
                if (runs != null) return runs.joinToString("") { it["text"] as? String ?: "" }
            }
        }
        val videoRenderer = obj["videoRenderer"] as? Map<String, Any>
            ?: obj["compactVideoRenderer"] as? Map<String, Any>
            ?: obj["gridVideoRenderer"] as? Map<String, Any>
            ?: obj["reelItemRenderer"] as? Map<String, Any>

        return extractTitle(videoRenderer)
    }
    
    // دالة مجمعة لتحليل جميع أنواع Renderers وإنشاء SearchResponse
    private fun parseRenderer(renderer: Map<String, Any>): SearchResponse? {
        val videoRenderer = renderer["videoRenderer"] as? Map<String, Any>
            ?: renderer["compactVideoRenderer"] as? Map<String, Any>
            ?: renderer["gridVideoRenderer"] as? Map<String, Any>
            ?: (renderer["richItemRenderer"] as? Map<String, Any>)?.get("content")?.get("videoRenderer") as? Map<String, Any>

        val reelRenderer = renderer["reelItemRenderer"] as? Map<String, Any>
            ?: (renderer["richItemRenderer"] as? Map<String, Any>)?.get("content")?.get("reelItemRenderer") as? Map<String, Any>

        val videoId = (videoRenderer?.get("videoId") ?: reelRenderer?.get("videoId")) as? String ?: return null
        
        val isShort = reelRenderer != null || (videoRenderer?.get("navigationEndpoint") as? Map<String,Any>)?.get("reelWatchEndpoint") != null
        
        val title = extractTitle(videoRenderer ?: reelRenderer) ?: "(No Title)"
        val poster = (videoRenderer?.get("thumbnail") as? Map<String, Any> ?: reelRenderer?.get("thumbnail") as? Map<String, Any>)
            ?.get("thumbnails")?.let { (it as List<Map<String, Any>>).lastOrNull()?.get("url") as? String }
            ?.let { if(it.startsWith("//")) "https:$it" else it }

        return newMovieSearchResponse(
            if (isShort) "[Shorts] $title" else title,
            if (isShort) "$webUrl/shorts/$videoId" else "$webUrl/watch?v=$videoId",
            TvType.Movie
        ) {
            this.posterUrl = poster
        }
    }


    // =================================================================================
    // الصفحة الرئيسية - محاكاة `يوتيوبpage.py` بدقة
    // =================================================================================
    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val items = mutableListOf<HomePageList>()
        val doc = app.get(webUrl, cookies = mapOf("VISITOR_INFO1_LIVE" to "fzYjM8PCwjw")).document
        val initialData = extractYtInitialData(doc.html())
        val ytcfg = extractYtCfg(doc.html())

        val contents = getFromPath(initialData, "contents.twoColumnBrowseResultsRenderer.tabs.0.tabRenderer.content.richGridRenderer.contents") as? List<Map<String, Any>>
        
        if (contents != null) {
            val mainPageItems = mutableListOf<SearchResponse>()
            var continuationToken: String? = null
            
            for (item in contents) {
                parseRenderer(item)?.let { mainPageItems.add(it) }
                
                // البحث عن continuation token
                val continuationRenderer = item["continuationItemRenderer"] as? Map<String, Any>
                continuationToken = continuationToken ?: (continuationRenderer?.get("continuationEndpoint") as? Map<String, Any>)
                    ?.get("continuationCommand")?.get("token") as? String
            }

            // تخزين بيانات continuation للصفحة التالية
            val loadData = if (continuationToken != null && ytcfg != null) {
                toJson(ContinuationPayload(continuationToken, ytcfg.apiKey, ytcfg.clientVersion, ytcfg.visitorData))
            } else null
            
            items.add(HomePageList("مقاطع مقترحة", mainPageItems, data = loadData))
        }

        return HomePageResponse(items)
    }

    override suspend fun loadPage(url: String): LoadPageResponse? {
        val contData = parseJson<ContinuationPayload>(url)
        val apiKey = contData.apiKey ?: return null
        val token = contData.token
        
        val payload = mapOf(
            "context" to mapOf(
                "client" to mapOf(
                    "visitorData" to (contData.visitorData ?: ""),
                    "clientName" to "WEB",
                    "clientVersion" to (contData.clientVersion ?: "2.20251114.01.00")
                )
            ),
            "continuation" to token
        )
        val res = app.post(
            "$webUrl/youtubei/v1/browse?key=$apiKey",
            json = payload
        ).parsed<Map<String, Any>>()
        
        val nextItems = (res["onResponseReceivedActions"] as? List<Map<String, Any>>)
            ?.flatMap { it.values }
            ?.filterIsInstance<Map<String, Any>>()
            ?.firstOrNull { it.containsKey("continuationItems") }
            ?.get("continuationItems") as? List<Map<String, Any>> ?: return null

        val videoList = mutableListOf<SearchResponse>()
        var newContinuationToken: String? = null
        for (item in nextItems) {
            parseRenderer(item)?.let { videoList.add(it) }
            val continuationRenderer = item["continuationItemRenderer"] as? Map<String, Any>
            newContinuationToken = newContinuationToken ?: (continuationRenderer?.get("continuationEndpoint") as? Map<String, Any>)
                ?.get("continuationCommand")?.get("token") as? String
        }
        
        val nextUrl = if (newContinuationToken != null) {
            toJson(contData.copy(token = newContinuationToken))
        } else null
        
        return LoadPageResponse(nextUrl, videoList)
    }

    // =================================================================================
    // البحث - محاكاة `يوتيوبsearch.py` بدقة
    // =================================================================================
    override suspend fun search(query: String): List<SearchResponse> {
        val searchUrl = "$mUrl/results?sp=mAEA&search_query=${query}"
        val doc = app.get(searchUrl).document
        
        val initialData = extractYtInitialData(doc.html()) ?: return emptyList()
        val ytcfg = extractYtCfg(doc.html())

        val contents = getFromPath(initialData, "contents.twoColumnSearchResultsRenderer.primaryContents.sectionListRenderer.contents") as? List<Map<String, Any>> ?: return emptyList()

        val results = mutableListOf<SearchResponse>()
        var continuationToken: String? = null

        for (section in contents) {
            val itemSection = section["itemSectionRenderer"] as? Map<String, Any>
            val sectionContents = itemSection?.get("contents") as? List<Map<String, Any>>
            if (sectionContents != null) {
                for (item in sectionContents) {
                    parseRenderer(item)?.let { results.add(it) }
                    val contRenderer = item["continuationItemRenderer"] as? Map<String, Any>
                    continuationToken = continuationToken ?: (contRenderer?.get("continuationEndpoint") as? Map<String, Any>)
                        ?.get("continuationCommand")?.get("token") as? String
                }
            }
        }
        
        // جلب صفحات البحث التالية (حتى 3 صفحات للسرعة)
        var page = 0
        while (continuationToken != null && page < 3) {
            page++
            val payload = mapOf(
                "context" to mapOf("client" to mapOf("clientName" to "MWEB", "clientVersion" to (ytcfg?.clientVersion ?: "2.20240725.01.00"))),
                "continuation" to continuationToken
            )
            val res = app.post("$mUrl/youtubei/v1/search?key=${ytcfg?.apiKey}", json = payload).parsed<Map<String, Any>>()
            
            val nextContents = getFromPath(res, "onResponseReceivedCommands.0.appendContinuationItemsAction.continuationItems") as? List<Map<String, Any>> ?: break
            
            for (item in nextContents) {
                parseRenderer(item)?.let { results.add(it) }
                val contRenderer = item["continuationItemRenderer"] as? Map<String, Any>
                continuationToken = (contRenderer?.get("continuationEndpoint") as? Map<String, Any>)
                        ?.get("continuationCommand")?.get("token") as? String
            }
        }
        
        // محاولة جلب العناوين المفقودة عبر oEmbed (نفس منطق كودك)
        val missingTitles = results.filter { it.name == "(No Title)" }.take(20) // حد 20 لتجنب البطء
        if (missingTitles.isNotEmpty()) {
            missingTitles.apmap { video ->
                try {
                    val oembedUrl = "$webUrl/oembed?url=${video.url}&format=json"
                    val oembedRes = app.get(oembedUrl).parsed<OembedResponse>()
                    video.name = oembedRes.title ?: video.name
                } catch (e: Exception) {
                    // Ignore
                }
            }
        }
        
        return results
    }

    // =================================================================================
    // جلب الروابط - محاكاة `يوتيوبm3u.py` بدقة
    // =================================================================================

    // `load` هنا فقط لجلب البيانات الأولية للعرض في صفحة الفيلم
    override suspend fun load(url: String): LoadResponse? {
        val videoId = url.substringAfter("v=").substringBefore("&").substringAfter("/shorts/")
        val doc = app.get("$webUrl/watch?v=$videoId").document
        
        val initialData = extractYtInitialData(doc.html())
        val videoDetails = getFromPath(initialData, "contents.twoColumnWatchNextResults.results.results.contents.0.videoPrimaryInfoRenderer") as? Map<String, Any>
            ?: getFromPath(initialData, "playerOverlays.playerOverlayRenderer.videoDetails.playerOverlayVideoDetailsRenderer") as? Map<String, Any>
        
        val title = extractTitle(videoDetails) ?: "Loading..."
        val poster = doc.select("meta[property=og:image]").attr("content")
        val plot = doc.select("meta[property=og:description]").attr("content")

        return newMovieLoadResponse(title, url, TvType.Movie, url) {
            this.posterUrl = poster
            this.plot = plot
        }
    }
    
    // `loadLinks` هنا ينفذ كل العمل الحقيقي لجلب الروابط
    override suspend fun loadLinks(
        data: String, // `data` هو الرابط الأصلي للفيديو
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val videoId = data.substringAfter("v=").substringBefore("&").substringAfter("/shorts/")
        
        // نفس هوية Safari من كودك
        val safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

        // الخطوة 1: جلب الإعدادات من صفحة /watch
        val watchUrl = "$webUrl/watch?v=$videoId&hl=en"
        val watchDoc = app.get(watchUrl, headers = mapOf("User-Agent" to safariUserAgent)).document
        val ytcfg = extractYtCfg(watchDoc.html()) ?: return false
        val apiKey = ytcfg.apiKey ?: return false
        val visitorData = ytcfg.visitorData ?: return false

        // الخطوة 2: استدعاء API المشغل بهوية Safari
        val apiUrl = "$webUrl/youtubei/v1/player?key=$apiKey"
        val payload = mapOf(
            "context" to mapOf(
                "client" to mapOf(
                    "hl" to "en", "gl" to "US", "clientName" to "WEB",
                    "clientVersion" to (ytcfg.clientVersion ?: "2.20240725.01.00"), 
                    "userAgent" to safariUserAgent,
                    "visitorData" to visitorData
                )
            ),
            "videoId" to videoId
        )
        
        val apiResponse = app.post(apiUrl, json = payload).parsed<Map<String, Any>>()

        // الخطوة 3: البحث عن hlsManifestUrl
        val hlsManifestUrl = getFromPath(apiResponse, "streamingData.hlsManifestUrl") as? String ?: return false

        // الخطوة 4: جلب ملف M3U8 النهائي
        return M3u8Helper.generateM3u8(
            this.name,
            hlsManifestUrl,
            webUrl,
            headers = mapOf("User-Agent" to safariUserAgent)
        ).forEach(callback).let { true } // إرجاع true إذا تم استدعاء callback
    }
    
    // دالة مساعدة للتنقل في القواميس المتداخلة
    private fun getFromPath(obj: Any?, path: String): Any? {
        var current: Any? = obj
        path.split('.').forEach { key ->
            current = if (key.toIntOrNull() != null) {
                (current as? List<*>)?.getOrNull(key.toInt())
            } else {
                (current as? Map<*, *>)?.get(key)
            }
        }
        return current
    }
}
