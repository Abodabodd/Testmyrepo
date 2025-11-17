package com.arabseed

import android.util.Log
import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*
import org.jsoup.Jsoup
import com.lagradost.cloudstream3.network.CloudflareKiller
import com.lagradost.cloudstream3.utils.Qualities
import kotlinx.serialization.Serializable
import com.lagradost.cloudstream3.MainAPI
import com.lagradost.cloudstream3.TvType
import com.lagradost.cloudstream3.utils.ExtractorLink
import org.json.JSONObject
import java.net.URLEncoder
import java.util.regex.Pattern

class YouTubeProvider : MainAPI() {
    override var mainUrl = "https://www.youtube.com"
    override var name = "YouTube (m)"
    override var lang = "ar"
    override val hasMainPage = false
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries, TvType.Anime)

    private fun String.toAbsolute(): String {
        if (this.isBlank()) return ""
        return when {
            this.startsWith("http") -> this
            this.startsWith("//") -> "https:$this"
            else -> mainUrl.trimEnd('/') + this
        }
    }

    // ---------------------------- Helpers ----------------------------
    private fun newExtractor(url: String, title: String = "YouTube", qualityLabel: String = "HLS"): ExtractorLink {
        // This helper guarantees a consistent ExtractorLink creation
        // If your project expects a different constructor signature, adjust here.
        return ExtractorLink(url, "$title - $qualityLabel", "m3u8")
    }

    private fun extractJsonVar(html: String, varName: String): String? {
        // try common patterns: var ytInitialData = {...}; window["ytInitialData"] = {...};
        val p1 = Pattern.compile("$varName\\s*=\\s*(\\{.+?\\})\\s*;", Pattern.DOTALL)
        val m1 = p1.matcher(html)
        if (m1.find()) return m1.group(1)
        // alternative: "ytcfg.set({...})"
        val p2 = Pattern.compile("ytcfg\\.set\\((\\{.+?\\})\\)", Pattern.DOTALL)
        val m2 = p2.matcher(html)
        if (m2.find()) return m2.group(1)
        // alternative for INNERTUBE_API_KEY as plain string
        val p3 = Pattern.compile("\"INNERTUBE_API_KEY\"\\s*:\\s*\"([^\"]+)\"")
        val m3 = p3.matcher(html)
        if (m3.find()) return JSONObject().put("INNERTUBE_API_KEY", m3.group(1)).toString()
        return null
    }

    private fun fetchInnertubeKey(html: String): String? {
        // attempt multiple ways
        try {
            val p = Pattern.compile("INNERTUBE_API_KEY\"\\s*:\\s*\"([^\"]+)\"")
            val m = p.matcher(html)
            if (m.find()) return m.group(1)
            val ytcfg = extractJsonVar(html, "ytcfg.set")
            if (ytcfg != null) {
                val j = JSONObject(ytcfg)
                if (j.has("INNERTUBE_API_KEY")) return j.getString("INNERTUBE_API_KEY")
            }
        } catch (_: Exception) {}
        return null
    }

    private fun findVisitorData(html: String): String? {
        val p = Pattern.compile("VISITOR_DATA\"\\s*:\\s*\"([^\"]+)\"")
        val m = p.matcher(html)
        if (m.find()) return m.group(1)
        return null
    }

    // ---------------------------- Search ----------------------------
    override suspend fun search(query: String): List<SearchResponse> {
        // Implementation: use m.youtube.com simple search page; fallback to youtube search page
        val q = URLEncoder.encode(query.trim(), "utf-8")
        val url = "https://m.youtube.com/results?sp=mAEA&search_query=$q"
        Log.i(name, "search: $query -> $url")
        return try {
            val resp = app.get(url)
            val html = resp.text
            // try to extract initialData JSON and parse video renderers
            val ytJsonStr = extractJsonVar(html, "ytInitialData")
            val out = mutableListOf<SearchResponse>()

            if (ytJsonStr != null) {
                try {
                    val json = JSONObject(ytJsonStr)
                    val nodes = AppUtils.searchJson(json, arrayOf("videoRenderer", "compactVideoRenderer", "gridVideoRenderer"))
                    for (n in nodes) {
                        try {
                            val vid = AppUtils.parseJsonValue(n, arrayOf("videoId", "id")) ?: continue
                            val title = AppUtils.parseJsonValue(n, arrayOf("title", "runs", "0", "text")) ?:
                                        AppUtils.parseJsonValue(n, arrayOf("title", "simpleText")) ?: vid
                            val thumb = "https://i.ytimg.com/vi/$vid/mqdefault.jpg"
                            val link = "https://www.youtube.com/watch?v=$vid"
                            out.add(newMovieSearchResponse(title, link, TvType.Movie) { this.posterUrl = thumb })
                        } catch (_: Exception) {}
                    }
                } catch (e: Exception) {
                    Log.w(name, "search-json-parse", e)
                }
            } else {
                // fallback: attempt to parse search result links from mobile HTML using Jsoup
                val doc = Jsoup.parse(html)
                doc.select("a").forEach { a ->
                    val href = a.attr("href")
                    if (href.contains("/watch")) {
                        val vid = Regex("""v=([a-zA-Z0-9_-]{11})""").find(href)?.groupValues?.get(1)
                        if (vid != null) {
                            val title = a.attr("title").ifBlank { a.text() }.ifBlank { vid }
                            val thumb = "https://i.ytimg.com/vi/$vid/mqdefault.jpg"
                            val link = "https://www.youtube.com/watch?v=$vid"
                            out.add(newMovieSearchResponse(title, link, TvType.Movie) { this.posterUrl = thumb })
                        }
                    }
                }
            }
            out
        } catch (e: Exception) {
            Log.e(name, "search error", e)
            emptyList()
        }
    }

    // ---------------------------- Load (page -> episodes / movie) ----------------------------
    override suspend fun load(url: String): LoadResponse {
        Log.i(name, "load: $url")
        return try {
            val resp = app.get(url)
            val doc = resp.document
            val title = doc.selectFirst("title")?.text()?.trim() ?: "YouTube Video"
            val synopsis = doc.selectFirst("meta[name=description]")?.attr("content") ?: ""
            // For our provider we can't produce episodes from YouTube; we will return a Movie load response
            newMovieLoadResponse(title, url, TvType.Movie, url) {
                this.plot = synopsis
                // poster: try to find video id in url
                val vid = Regex("""v=([a-zA-Z0-9_-]{11})""").find(url)?.groupValues?.get(1)
                if (vid != null) this.posterUrl = "https://i.ytimg.com/vi/$vid/maxresdefault.jpg"
            }
        } catch (e: Exception) {
            Log.e(name, "load error", e)
            newMovieLoadResponse("خطأ", url, TvType.Movie, url)
        }
    }

    @Serializable
    data class PlayerResponse(val streamingData: Map<String, Any>?)

    // ---------------------------- loadLinks (core) ----------------------------
    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        Log.i(name, "loadLinks initiated for: $data")

        try {
            val pageResp = app.get(data)
            val pageHtml = pageResp.text
            // extract video id
            val vid = Regex("""v=([a-zA-Z0-9_-]{11})""").find(data)?.groupValues?.get(1)
                ?: Regex("""/shorts/([a-zA-Z0-9_-]{11})""").find(data)?.groupValues?.get(1)
                ?: run {
                    // try find from meta
                    Regex("""/vi/([a-zA-Z0-9_-]{11})/""").find(pageHtml)?.groupValues?.get(1)
                }

            if (vid == null) {
                Log.e(name, "video id not found for $data")
                return false
            }

            val watchUrl = "https://www.youtube.com/watch?v=$vid&hl=en"
            Log.d(name, "watchUrl: $watchUrl")

            // fetch watch page HTML (to get ytcfg / INNERTUBE_API_KEY / VISITOR_DATA)
            val watchResp = app.get(watchUrl, referer = data)
            val watchHtml = watchResp.text

            val apiKey = fetchInnertubeKey(watchHtml) ?: run {
                Log.e(name, "INNERTUBE_API_KEY not found")
                return false
            }
            val visitor = findVisitorData(watchHtml) ?: ""

            Log.d(name, "found apiKey length=${apiKey.length}, visitorData=${visitor.isNotBlank()}")

            // construct payload JSON
            val context = JSONObject()
            val client = JSONObject()
            client.put("hl", "en")
            client.put("gl", "US")
            client.put("clientName", "WEB")
            client.put("clientVersion", "2.20240725.01.00")
            if (visitor.isNotBlank()) client.put("visitorData", visitor)
            context.put("client", client)
            val payload = JSONObject()
            payload.put("context", context)
            payload.put("videoId", vid)

            val apiUrl = "https://www.youtube.com/youtubei/v1/player?key=$apiKey"
            Log.d(name, "player API URL: $apiUrl")

            val apiResp = try {
                // app.post with JSON body: this call returns Response, use .text
                app.post(apiUrl, data = payload.toString(), headers = mapOf("Content-Type" to "application/json"), referer = watchUrl).text
            } catch (e: Exception) {
                Log.e(name, "player API request failed", e)
                return false
            }

            // parse API response
            val apiJson = JSONObject(apiResp)
            if (!apiJson.has("streamingData")) {
                Log.e(name, "player API: streamingData not found")
                // sometimes YouTube blocks; fallback to attempt to find m3u8 in watchHtml
                val m = Regex("(https?://[^\\s'\"<>]+\\.m3u8[^\\s'\"<>]*)").find(watchHtml)
                if (m != null) {
                    val m3u8 = m.groupValues[1]
                    Log.d(name, "fallback found m3u8: $m3u8")
                    callback(newExtractor(m3u8, "YouTube", "hls"))
                    return true
                }
                return false
            }

            val streaming = apiJson.getJSONObject("streamingData")
            // prioritize hlsManifestUrl
            if (streaming.has("hlsManifestUrl")) {
                val hls = streaming.getString("hlsManifestUrl")
                Log.i(name, "Found hlsManifestUrl: $hls")
                try {
                    val m3u8Text = app.get(hls).text
                    // parse m3u8 lines for variant URIs
                    val lines = m3u8Text.split("\n")
                    var count = 0
                    for (ln in lines) {
                        val l = ln.trim()
                        if (l.startsWith("http://") || l.startsWith("https://")) {
                            // call callback with each variant
                            callback(newExtractor(l, "YouTube", "HLS-$count"))
                            count++
                        }
                    }
                    if (count == 0) {
                        // if no variant lines, return the manifest itself
                        callback(newExtractor(hls, "YouTube", "manifest"))
                    }
                    return true
                } catch (e: Exception) {
                    Log.e(name, "Failed to fetch/parse m3u8, fallback to manifest", e)
                    callback(newExtractor(hls, "YouTube", "hls"))
                    return true
                }
            } else {
                // fallback: look into formats/adaptiveFormats for direct URLs
                try {
                    val formats = mutableListOf<String>()
                    if (streaming.has("formats")) {
                        val arr = streaming.getJSONArray("formats")
                        for (i in 0 until arr.length()) {
                            val it = arr.getJSONObject(i)
                            if (it.has("url")) {
                                formats.add(it.getString("url"))
                            } else if (it.has("signatureCipher") || it.has("cipher")) {
                                // ciphered url -> complicated to decipher here; skip
                            }
                        }
                    }
                    if (streaming.has("adaptiveFormats")) {
                        val arr2 = streaming.getJSONArray("adaptiveFormats")
                        for (i in 0 until arr2.length()) {
                            val it = arr2.getJSONObject(i)
                            if (it.has("url")) formats.add(it.getString("url"))
                        }
                    }
                    if (formats.isNotEmpty()) {
                        formats.distinct().forEachIndexed { idx, u -> callback(newExtractor(u, "YouTube", "prog-$idx")) }
                        return true
                    }
                } catch (e: Exception) {
                    Log.w(name, "formats parsing failed", e)
                }
            }

            // final fallback: attempt to find an iframe or embed and use loadExtractor
            val iframeMatch = Regex("<iframe[^>]+src=[\"']([^\"']+)[\"']").find(watchHtml)
            if (iframeMatch != null) {
                val iframeUrl = iframeMatch.groupValues[1]
                Log.i(name, "Found iframe fallback: $iframeUrl -> will use loadExtractor")
                // use loadExtractor helper (present in many providers) to handle common iframe-hosts
                try {
                    loadExtractor(iframeUrl, watchUrl, subtitleCallback, callback)
                    return true
                } catch (e: Exception) {
                    Log.e(name, "loadExtractor failed", e)
                }
            }

            Log.w(name, "No playable links found for $data")
            return false

        } catch (e: Exception) {
            Log.e(name, "loadLinks top-level error", e)
            return false
        }
    }
}
