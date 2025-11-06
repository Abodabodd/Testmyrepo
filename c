override suspend fun loadLinks(
    data: String,
    isCasting: Boolean,
    subtitleCallback: (SubtitleFile) -> Unit,
    callback: (ExtractorLink) -> Unit
): Boolean {
    Log.d(TAG, "loadLinks ▶ start — data=$data")

    // ------------------ بداية الدوال المدمجة ------------------

    // helper: تحويل رقم إلى تمثيل في قاعدة (0..35)
    fun intToBaseStr(n: Int, baseNum: Int): String {
        val digits = "0123456789abcdefghijklmnopqrstuvwxyz"
        return if (n < baseNum) digits.getOrNull(n)?.toString() ?: "" 
        else intToBaseStr(n / baseNum, baseNum) + (digits.getOrNull(n % baseNum) ?: "")
    }

    // helper: فك هروب JS داخل payload مثل \xNN و \uNNNN و escaped quotes/backslashes
    fun jsUnescape(s: String): String {
        var r = s
        // \xNN
        r = Regex("""\\x([0-9a-fA-F]{2})""").replace(r) { mr ->
            try {
                val v = mr.groupValues[1]
                (v.toInt(16)).toChar().toString()
            } catch (e: Exception) {
                mr.value
            }
        }
        // \uNNNN
        r = Regex("""\\u([0-9a-fA-F]{4})""").replace(r) { mr ->
            try {
                val v = mr.groupValues[1]
                (v.toInt(16)).toChar().toString()
            } catch (e: Exception) {
                mr.value
            }
        }
        r = r.replace("""\"""", "\"").replace("""\'""", "'").replace("""\\""", "\\")
        r = r.replace("""\n""", "\n").replace("""\r""", "\r").replace("""\t""", "\t")
        return r
    }

    // unpacker: مرن لالتقاط payload و dict و base و count
    fun unpackJs(packedJs: String): String? {
        try {
            Log.d(TAG, "unpackJs ▶ trying to unpack content length=${packedJs.length}")

            val regex = Regex(
                """eval\(function\(p,a,c,k,e,d\)\{[\s\S]*?\}\s*\(\s*(['"])(.*?)\1\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(['"])(.*?)\5\.split\(['"]\|['"]\)\s*\)\s*\)""",
                RegexOption.DOT_MATCHES_ALL
            )
            val m = regex.find(packedJs)
            if (m == null) {
                Log.w(TAG, "unpackJs ▶ regex did not match the packed pattern")
                return null
            }

            // groupIndices:
            // groupValues[2] = payload, [3] = base, [4] = count, [6] = dictionary
            val payloadRaw = m.groupValues[2]
            val base = m.groupValues[3].toIntOrNull() ?: run {
                Log.w(TAG, "unpackJs ▶ base parse failed")
                return null
            }
            val count = m.groupValues[4].toIntOrNull() ?: run {
                Log.w(TAG, "unpackJs ▶ count parse failed")
                return null
            }
            val dictRaw = m.groupValues[6]
            val dictionary = dictRaw.split("|")

            Log.d(TAG, "unpackJs ▶ captured base=$base count=$count dictLen=${dictionary.size} payloadLen=${payloadRaw.length}")

            // فك هروب الـ payload أولاً
            val payload = jsUnescape(payloadRaw)

            // بناء جدول البحث (lookup)
            val lookup = mutableMapOf<String, String>()
            for (i in (count - 1) downTo 0) {
                val key = try { intToBaseStr(i, base) } catch (e: Exception) { i.toString() }
                val value = dictionary.getOrNull(i)?.ifBlank { key } ?: key
                lookup[key] = value
            }

            // استبدال التوكنات (كلمات أبجدي-رقمية)
            val tokenRegex = Regex("""\b[a-zA-Z0-9]+\b""")
            val unpacked = tokenRegex.replace(payload) { mr ->
                lookup[mr.value] ?: mr.value
            }

            if (unpacked.isBlank()) {
                Log.w(TAG, "unpackJs ▶ Unpacked result is blank.")
                return null
            }

            Log.d(TAG, "unpackJs ▶ unpack success, length=${unpacked.length}")
            return unpacked
        } catch (e: Exception) {
            Log.e(TAG, "unpackJs ▶ exception", e)
            return null
        }
    }

    // استخراج رابط الفيديو من نص HTML/JS مفكوك أو خام
    fun findVideoInText(text: String): String? {
        // عدة أنماط للبحث
        val patterns = listOf(
            Regex("""file\s*:\s*"(https?://[^"]+)"""),
            Regex("""file\s*:\s*'(https?://[^']+)'"""),
            Regex("""src\s*:\s*"(https?://[^"]+)"""),
            Regex("""src\s*:\s*'(https?://[^']+)'"""),
            Regex("https?://[^\\s\"']+\\.m3u8[^\\s\"']*"),
            Regex("https?://[^\\s\"']+\\.mp4[^\\s\"']*")
        )
        for (p in patterns) {
            val m = p.find(text)
            if (m != null) return m.value.trim('"', '\'')
        }
        // JSON-like src: "file":"http..."
        val jsonFile = Regex(""""file"\s*:\s*"([^"]+)"""").find(text)
        if (jsonFile != null) return jsonFile.groupValues[1]
        return null
    }

    // دالة استخراج الرابط من صفحة التضمين (suspend)
    suspend fun extractFromEmbed(embedUrl: String, referer: String) {
        try {
            Log.d(TAG, "extractFromEmbed ▶ GET $embedUrl (referer=$referer)")
            val embedResp = app.get(embedUrl, referer = referer, timeout = 15)
            val embedText = embedResp.text

            // محاولة 0: ابحث عن رابط مباشر في الصفحة قبل أي فك
            val direct = findVideoInText(embedText)
            if (!direct.isNullOrBlank()) {
                Log.i(TAG, "extractFromEmbed ▶ direct video found -> $direct")
                callback(newExtractorLink(this@BrstejProvider.name, "${this@BrstejProvider.name} (direct)", direct) {
                    this.referer = embedUrl
                    this.quality = Qualities.Unknown.value
                    this.isM3u8 = direct.contains(".m3u8")
                })
                return
            }

            // محاولة 1: البحث عن packed eval(...) في الصفحة
            val packedJsMatch = Regex(
                """eval\(function\(p,a,c,k,e,d\)\s*\{[\s\S]+?\}\s*\([\s\S]+?\)\)""",
                RegexOption.DOT_MATCHES_ALL
            ).find(embedText)

            if (packedJsMatch == null) {
                Log.w(TAG, "extractFromEmbed ▶ no packed eval(...) found for $embedUrl — fallback to embedUrl")
                // fallback: return embed url itself as last resort
                callback(newExtractorLink(this@BrstejProvider.name, "${this@BrstejProvider.name} - embed (fallback)", embedUrl) {
                    this.referer = referer
                    this.quality = Qualities.Unknown.value
                    this.isM3u8 = embedUrl.contains(".m3u8")
                })
                return
            }

            val packedJsCode = packedJsMatch.value
            Log.d(TAG, "extractFromEmbed ▶ packed script found length=${packedJsCode.length}")

            // محاولة 2: JsUnpacker المدمجة
            var unpacked: String? = try {
                JsUnpacker(packedJsCode).unpack()
            } catch (e: Exception) {
                Log.w(TAG, "extractFromEmbed ▶ JsUnpacker threw: ${e.message}")
                null
            }

            // محاولة 3: unpack اليدوي
            if (unpacked.isNullOrBlank()) {
                Log.d(TAG, "extractFromEmbed ▶ JsUnpacker failed or returned blank — trying manual unpackJs")
                unpacked = unpackJs(packedJsCode)
            }

            // محاولة 4: لو ما زال فارغ — حاول استخراج أي روابط من الـ packedJs نفسه (أحيانًا payload مخبأ)
            if (unpacked.isNullOrBlank()) {
                Log.w(TAG, "extractFromEmbed ▶ unpacking failed for $embedUrl — scanning page for any https links as fallback")
                val pageFallback = findVideoInText(embedText)
                if (!pageFallback.isNullOrBlank()) {
                    Log.i(TAG, "extractFromEmbed ▶ fallback found -> $pageFallback")
                    callback(newExtractorLink(this@BrstejProvider.name, "${this@BrstejProvider.name} (fallback)", pageFallback) {
                        this.referer = embedUrl
                        this.quality = Qualities.Unknown.value
                        this.isM3u8 = pageFallback.contains(".m3u8")
                    })
                    return
                }

                // إرسال fallback إلى المستخدم (لو لم يعثر شيء)
                callback(newExtractorLink(this@BrstejProvider.name, "${this@BrstejProvider.name} - embed (fallback)", embedUrl) {
                    this.referer = referer
                    this.quality = Qualities.Unknown.value
                    this.isM3u8 = embedUrl.contains(".m3u8")
                })
                return
            }

            Log.d(TAG, "extractFromEmbed ▶ unpacked length=${unpacked.length}")

            // البحث عن رابط الفيديو داخل الشيفرة المفكوكة
            val fileMatch = Regex("""file\s*:\s*"(https?://[^"]+)"""").find(unpacked)
            if (fileMatch != null) {
                val videoUrl = fileMatch.groupValues[1]
                Log.i(TAG, "extractFromEmbed ▶ extracted video url -> $videoUrl")
                callback(newExtractorLink(this@BrstejProvider.name, "${this@BrstejProvider.name} (unpacked)", videoUrl) {
                    this.referer = embedUrl
                    this.quality = Qualities.Unknown.value
                    this.isM3u8 = videoUrl.contains(".m3u8")
                })
                return
            }

            // محاولة إضافية: البحث عن أي رابط m3u8 أو mp4 داخل النص المفكوك
            val anyLink = Regex("""https?://[^\s'"]+\.(?:m3u8|mp4)[^\s'"]*""").find(unpacked)
            if (anyLink != null) {
                val videoUrl = anyLink.value
                Log.i(TAG, "extractFromEmbed ▶ found direct media in unpacked -> $videoUrl")
                callback(newExtractorLink(this@BrstejProvider.name, "${this@BrstejProvider.name} (unpacked-media)", videoUrl) {
                    this.referer = embedUrl
                    this.quality = Qualities.Unknown.value
                    this.isM3u8 = videoUrl.contains(".m3u8")
                })
                return
            }

            // لو وصلنا هنا — لم نجد رابط في الـ unpacked
            Log.w(TAG, "extractFromEmbed ▶ no file found in unpacked script for $embedUrl — sending fallback")
            callback(newExtractorLink(this@BrstejProvider.name, "${this@BrstejProvider.name} - embed (fallback)", embedUrl) {
                this.referer = referer
                this.quality = Qualities.Unknown.value
                this.isM3u8 = embedUrl.contains(".m3u8")
            })
        } catch (e: Exception) {
            Log.e(TAG, "extractFromEmbed ▶ unexpected error for $embedUrl", e)
            callback(newExtractorLink(this@BrstejProvider.name, "${this@BrstejProvider.name} - embed (error)", embedUrl) {
                this.referer = referer
                this.quality = Qualities.Unknown.value
                this.isM3u8 = embedUrl.contains(".m3u8")
            })
        }
    }

    // ------------------ نهاية الدوال المدمجة ------------------

    try {
        val watchDoc = app.get(data, referer = mainUrl, timeout = 15).document
        val playHrefRaw = watchDoc.selectFirst("a.xtgo")?.attr("href") ?: run {
            Log.w(TAG, "loadLinks ▶ a.xtgo not found for $data")
            return false
        }
        val playUrl = buildAbsoluteUrl(playHrefRaw)
        Log.d(TAG, "loadLinks ▶ playUrl = $playUrl")
        val playDoc = app.get(playUrl, referer = data, timeout = 15).document

        val processedUrls = mutableSetOf<String>()

        kotlinx.coroutines.coroutineScope {
            // extract from WatchServers buttons
            playDoc.select("div#WatchServers button.watchButton, div#WatchServers button.watchbutton").forEach { btn ->
                val raw = btn.attr("data-embed-url").ifBlank { btn.attr("data-embed") }
                val embedUrl = raw?.let { buildAbsoluteUrl(it) } ?: ""
                if (embedUrl.isNotBlank() && processedUrls.add(embedUrl)) {
                    Log.d(TAG, "loadLinks ▶ found button embedUrl='$embedUrl'")
                    launch { extractFromEmbed(embedUrl, playUrl) }
                }
            }

            // iframe in Playerholder
            val iframeSrc = playDoc.selectFirst("div#Playerholder iframe")?.attr("src")?.let { buildAbsoluteUrl(it) }
            if (!iframeSrc.isNullOrBlank() && processedUrls.add(iframeSrc)) {
                Log.d(TAG, "loadLinks ▶ found iframe src='$iframeSrc'")
                launch { extractFromEmbed(iframeSrc, playUrl) }
            }

            // also scan any other iframe on the play page as extra
            playDoc.select("iframe").forEach { ifr ->
                val src = ifr.attr("src")
                val full = src.let { buildAbsoluteUrl(it) }
                if (full.isNotBlank() && processedUrls.add(full)) {
                    Log.d(TAG, "loadLinks ▶ found extra iframe src='$full'")
                    launch { extractFromEmbed(full, playUrl) }
                }
            }
        }

        Log.d(TAG, "loadLinks ▶ finished — processed ${processedUrls.size} embeds")
        return processedUrls.isNotEmpty()
    } catch (e: Exception) {
        Log.e(TAG, "loadLinks ▶ top-level error", e)
        return false
    }
}
