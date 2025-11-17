// YouTubeProvider.kt
// مصمم ليعمل كـ CloudStream provider ويطابق منطق سكربتات Python الثلاثة:
// - بحث (m.youtube.com + continuation)
// - صفحة الفيديو (ytcfg -> INNERTUBE_API_KEY, VISITOR_DATA)
// - استدعاء youtubei/v1/player للحصول على hlsManifestUrl ثم استخراج روابط M3U8
//
// راجع: phisher98 cloudstream repo style (used for structure). 3

package main

import com.lagradost.cloudstream3.MainAPI
import com.lagradost.cloudstream3.models.VideoInfo
import com.lagradost.cloudstream3.models.ExtractorLink
import com.lagradost.cloudstream3.models.Qualities
import com.lagradost.cloudstream3.utils.AppUtils
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder
import java.util.regex.Pattern

class YouTubeProvider : MainAPI() {
    override val name = "YouTube (m)"
    override val mainUrl = "https://www.youtube.com"
    override val lang = "ar"

    private val client = OkHttpClient()

    // Safari-like client context (matches what many implementations use)
    private val WEB_CLIENT_CONTEXT = JSONObject().apply {
        put("client", JSONObject().apply {
            put("hl", "en")
            put("gl", "US")
            put("clientName", "WEB")
            put("clientVersion", "2.20240725.01.00")
            put("userAgent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15")
        })
        put("user", JSONObject())
        put("request", JSONObject())
    }

    // ---------- HTTP helpers ----------
    private fun httpGet(url: String, extraHeaders: Map<String, String> = emptyMap()): String {
        val builder = Request.Builder().url(url)
            .header("User-Agent", WEB_CLIENT_CONTEXT.getJSONObject("client").getString("userAgent"))
            .header("Accept-Language", "en-US,en;q=0.5")
        extraHeaders.forEach { (k, v) -> builder.header(k, v) }
        val resp = client.newCall(builder.build()).execute()
        if (!resp.isSuccessful) throw Exception("HTTP ${resp.code} for $url")
        return resp.body?.string() ?: ""
    }

    private fun httpPostJson(url: String, json: JSONObject, extraHeaders: Map<String, String> = emptyMap()): String {
        val mediaType = "application/json; charset=utf-8".toMediaTypeOrNull()
        val body = json.toString().toRequestBody(mediaType)
        val builder = Request.Builder().url(url)
            .post(body)
            .header("User-Agent", WEB_CLIENT_CONTEXT.getJSONObject("client").getString("userAgent"))
            .header("Accept-Language", "en-US,en;q=0.5")
            .header("Content-Type", "application/json")
        extraHeaders.forEach { (k, v) -> builder.header(k, v) }
        val resp = client.newCall(builder.build()).execute()
        if (!resp.isSuccessful) throw Exception("HTTP ${resp.code} for $url")
        return resp.body?.string() ?: ""
    }

    // ---------- small utilities ----------
    private fun extractVideoId(url: String): String? {
        val patterns = listOf(
            "(?:v=|/|embed/|shorts/|v%3D|be/)([a-zA-Z0-9_-]{11})"
        )
        for (p in patterns) {
            val m = Pattern.compile(p).matcher(url)
            if (m.find()) return m.group(1)
        }
        return null
    }

    private fun extractJsonVariable(html: String, varName: String): JSONObject? {
        // common forms: var ytInitialData = {...}; or window["ytInitialData"] = {...};
        val p = Pattern.compile("$varName\\s*=\\s*(\\{.+?\\})\\s*;", Pattern.DOTALL)
        val m = p.matcher(html)
        if (m.find()) {
            try {
                return JSONObject(m.group(1))
            } catch (_: Exception) {}
        }
        // try ytcfg.set({...})
        val p2 = Pattern.compile("ytcfg\\.set\\((\\{.+?\\})\\)", Pattern.DOTALL)
        val m2 = p2.matcher(html)
        if (m2.find()) {
            try {
                return JSONObject(m2.group(1))
            } catch (_: Exception) {}
        }
        return null
    }

    private fun fetchInnertubeKeyFromHtml(html: String): String? {
        val p = Pattern.compile("INNERTUBE_API_KEY\"\\s*:\\s*\"([^\"]+)\"")
        val m = p.matcher(html)
        if (m.find()) return m.group(1)
        // alternative: ytcfg set object
        val p2 = Pattern.compile("ytcfg\\.set\\((\\{.+?\\})\\)", Pattern.DOTALL)
        val m2 = p2.matcher(html)
        if (m2.find()) {
            try {
                val j = JSONObject(m2.group(1))
                if (j.has("INNERTUBE_API_KEY")) return j.getString("INNERTUBE_API_KEY")
            } catch (_: Exception) {}
        }
        return null
    }

    private fun findVisitorDataFromHtml(html: String): String? {
        val p = Pattern.compile("VISITOR_DATA\"\\s*:\\s*\"([^\"]+)\"")
        val m = p.matcher(html)
        if (m.find()) return m.group(1)
        return null
    }

    // ---------- newExtractor helper (guarantee presence) ----------
    // Many repos call helper functions named newExtractor — to avoid missing-call problems
    // we define an internal helper that returns ExtractorLink instances in a standard way.
    private fun newExtractor(url: String, name: String = "YouTube HLS", qualityLabel: String = "HLS"): ExtractorLink {
        // ExtractorLink(url, name, "m3u8") is the common constructor — adapt if your CloudStream version differs.
        return ExtractorLink(url, "$name - $qualityLabel", "m3u8")
    }

    // ---------- Search (m.youtube.com results + continuations) ----------
    override suspend fun search(query: String): List<com.lagradost.cloudstream3.model.SearchResponse> {
        val out = mutableListOf<com.lagradost.cloudstream3.model.SearchResponse>()
        try {
            val q = URLEncoder.encode(query, "utf-8")
            val url = "https://m.youtube.com/results?sp=mAEA&search_query=$q"
            val html = httpGet(url)

            // extract ytInitialData (search results)
            val initial = extractJsonFromHtmlTry(html, "ytInitialData")
            if (initial != null) {
                parseSearchJson(initial, out)
                // continuation tokens handling
                var cont = findContinuationToken(initial)
                var pages = 0
                val apiKey = fetchInnertubeKeyFromHtml(html) ?: ""
                while (!cont.isNullOrEmpty() && pages < 8) {
                    try {
                        val contUrl = "https://www.youtube.com/youtubei/v1/search?key=$apiKey"
                        val payload = JSONObject()
                        payload.put("context", WEB_CLIENT_CONTEXT)
                        payload.put("continuation", cont)
                        val resp = httpPostJson(contUrl, payload)
                        val j = JSONObject(resp)
                        parseSearchJson(j, out)
                        cont = findContinuationToken(j)
                    } catch (e: Exception) {
                        break
                    }
                    pages++
                }
            }
        } catch (e: Exception) {
            AppUtils.log("YouTubeProvider", "search error: ${e.message}")
        }
        return out
    }

    // attempt to extract JSON variable by several common keys
    private fun extractJsonFromHtmlTry(html: String, key: String): JSONObject? {
        // try direct patterns
        try {
            val p = Pattern.compile("$key\\s*=\\s*(\\{.+?\\})\\s*;", Pattern.DOTALL)
            val m = p.matcher(html)
            if (m.find()) return JSONObject(m.group(1))
        } catch (_: Exception) {}
        // try window["ytInitialData"] variants
        try {
            val p2 = Pattern.compile("\"$key\"\\s*:\\s*(\\{.+?\\})\\s*[,}]?", Pattern.DOTALL)
            val m2 = p2.matcher(html)
            if (m2.find()) return JSONObject(m2.group(1))
        } catch (_: Exception) {}
        return null
    }

    private fun parseSearchJson(jobj: JSONObject, out: MutableList<com.lagradost.cloudstream3.model.SearchResponse>) {
        try {
            // search for videoRenderer nodes anywhere
            val items = AppUtils.searchJson(jobj, arrayOf("videoRenderer", "compactVideoRenderer", "gridVideoRenderer"))
            for (it in items) {
                try {
                    val id = AppUtils.parseJsonValue(it, arrayOf("videoId", "id")) ?: continue
                    val title = AppUtils.parseJsonValue(it, arrayOf("title", "runs", "0", "text")) ?:
                                AppUtils.parseJsonValue(it, arrayOf("title", "simpleText")) ?: id
                    val thumb = "https://i.ytimg.com/vi/$id/mqdefault.jpg"
                    val link = "https://www.youtube.com/watch?v=$id"
                    out.add(com.lagradost.cloudstream3.model.SearchResponse(title, link, thumb))
                } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            AppUtils.log("YouTubeProvider", "parseSearchJson: ${e.message}")
        }
    }

    private fun findContinuationToken(j: Any): String? {
        try {
            val root = when (j) {
                is String -> JSONObject(j)
                is JSONObject -> j
                else -> JSONObject(j.toString())
            }
            val nodes = AppUtils.searchJson(root, arrayOf("token", "continuation", "continuationEndpoint"))
            if (nodes.isNotEmpty()) {
                // try token field
                val t = AppUtils.parseJsonValue(nodes[0], arrayOf("token", "continuation"))
                if (!t.isNullOrEmpty()) return t
            }
        } catch (_: Exception) {}
        return null
    }

    // ---------- Load video info & streams ----------
    override suspend fun load(url: String): VideoInfo? {
        return try {
            val links = loadLinks(url)
            if (links.isEmpty()) null
            else {
                val vi = VideoInfo()
                vi.name = links.firstOrNull()?.name ?: "YouTube Video"
                // build streams mapping: use quality names as keys
                val streamsMap = mutableMapOf<String, String>()
                links.forEachIndexed { idx, l ->
                    streamsMap["${l.quality ?: "HLS"}"] = l.url
                }
                vi.streams = streamsMap
                vi
            }
        } catch (e: Exception) {
            AppUtils.log("YouTubeProvider", "load: ${e.message}")
            null
        }
    }

    // core: replicate youtubem3u.py logic
    suspend fun loadLinks(url: String): List<ExtractorLink> {
        val result = mutableListOf<ExtractorLink>()
        try {
            val vid = extractVideoId(url) ?: throw Exception("video id not found")
            val watchUrl = "https://www.youtube.com/watch?v=$vid&hl=en"
            val html = httpGet(watchUrl)

            // extract ytcfg object and INNERTUBE_API_KEY / VISITOR_DATA
            val ytcfg = extractYtcfgFromHtml(html) ?: throw Exception("ytcfg not found")
            val apiKey = if (ytcfg.has("INNERTUBE_API_KEY")) ytcfg.getString("INNERTUBE_API_KEY") else fetchInnertubeKeyFromHtml(html) ?: ""
            val visitorData = if (ytcfg.has("VISITOR_DATA")) ytcfg.getString("VISITOR_DATA") else findVisitorDataFromHtml(html) ?: ""

            if (apiKey.isEmpty()) throw Exception("INNERTUBE_API_KEY not found")

            // prepare context with visitorData
            val finalContext = JSONObject(WEB_CLIENT_CONTEXT.toString())
            try { finalContext.getJSONObject("client").put("visitorData", visitorData) } catch (_: Exception) {}

            val apiUrl = "https://www.youtube.com/youtubei/v1/player?key=$apiKey"
            val payload = JSONObject()
            payload.put("context", finalContext)
            payload.put("videoId", vid)

            val apiResp = httpPostJson(apiUrl, payload)
            val apiJson = JSONObject(apiResp)

            if (!apiJson.has("streamingData")) throw Exception("streamingData missing")
            val streaming = apiJson.getJSONObject("streamingData")
            // prefer hlsManifestUrl
            if (streaming.has("hlsManifestUrl")) {
                val hls = streaming.getString("hlsManifestUrl")
                // fetch m3u8 content
                try {
                    val m3u8 = httpGet(hls)
                    // parse m3u8 to get variant URIs (lines that start with http)
                    val lines = m3u8.split("\n")
                    var count = 0
                    for (ln in lines) {
                        val l = ln.trim()
                        if (l.startsWith("http://") || l.startsWith("https://")) {
                            // create extractor link via helper
                            result.add(newExtractor(l, "YouTube HLS", "HLS-$count"))
                            count++
                        }
                    }
                    // if none found, add the manifest itself
                    if (result.isEmpty()) {
                        result.add(newExtractor(hls, "YouTube HLS", "manifest"))
                    }
                } catch (e: Exception) {
                    // fallback: add raw hls URL
                    result.add(newExtractor(hls, "YouTube HLS", "hls"))
                }
            } else {
                // fallback: try progressive formats in streamingData.formats/adaptiveFormats
                if (streaming.has("formats")) {
                    val arr = streaming.getJSONArray("formats")
                    for (i in 0 until arr.length()) {
                        try {
                            val item = arr.getJSONObject(i)
                            if (item.has("url")) {
                                val u = item.getString("url")
                                result.add(newExtractor(u, "YouTube Progress", item.optString("qualityLabel", "prog")))
                            } else if (item.has("signatureCipher") || item.has("cipher")) {
                                // ciphered urls: harder to handle here — skipping (youtube often uses cipher)
                            }
                        } catch (_: Exception) {}
                    }
                }
                if (result.isEmpty()) {
                    // final fallback: try to find any m3u8 in html
                    val p = Pattern.compile("(https?:\\\\/\\\\/[^\\s'\"]+\\.m3u8[^\\s'\"]*)")
                    val m = p.matcher(html)
                    if (m.find()) result.add(newExtractor(m.group(1), "YouTubeFuzzyHLS", "hls"))
                }
            }
        } catch (e: Exception) {
            AppUtils.log("YouTubeProvider", "loadLinks error: ${e.message}")
        }
        return result
    }

    private fun extractYtcfgFromHtml(html: String): JSONObject? {
        try {
            val p = Pattern.compile("ytcfg\\.set\\((\\{.+?\\})\\)", Pattern.DOTALL)
            val m = p.matcher(html)
            if (m.find()) {
                try {
                    return JSONObject(m.group(1))
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
        return null
    }
}
