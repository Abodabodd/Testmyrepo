override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val TAG = "WitAnimeLinks"

        fun base64Decode(input: String?): String {
            if (input.isNullOrBlank()) return ""
            return try {
                String(android.util.Base64.decode(input, android.util.Base64.DEFAULT))
            } catch (e: Exception) {
                ""
            }
        }

        return try {
            val html = app.get(data).text

            // -------------------- Watch Links (x18c) --------------------
            val zG = Regex("""var\s+_zG\s*=\s*"([^"]+)"""").find(html)?.groupValues?.get(1)
            val zH = Regex("""var\s+_zH\s*=\s*"([^"]+)"""").find(html)?.groupValues?.get(1)

            val resourceRegistry: Map<String, Any>? = try {
                AppUtils.parseJson(base64Decode(zG))
            } catch (e: Exception) { null }

            val configRegistry: Map<String, Any>? = try {
                AppUtils.parseJson(base64Decode(zH))
            } catch (e: Exception) { null }

            // نجيب السيرفرات من الصفحة
            val serverRegex = Regex(
                """data-server-id=['"](\d+)['"].*?<span[^>]*class=["']ser["'][^>]*>(.*?)</span>""",
                RegexOption.DOT_MATCHES_ALL
            )
            val servers = serverRegex.findAll(html).map {
                val sid = it.groupValues[1]
                val label = it.groupValues[2].trim()
                sid to label
            }.toList()

            for ((sid, label) in servers) {
                val resourceRaw = when {
                    resourceRegistry?.containsKey(sid) == true -> resourceRegistry[sid].toString()
                    resourceRegistry?.containsKey(sid.toIntOrNull()?.toString() ?: "") == true ->
                        resourceRegistry?.get(sid.toIntOrNull()?.toString() ?: "").toString()
                    else -> null
                }

                if (!resourceRaw.isNullOrBlank()) {
                    // فك التشفير (reverse + base64)
                    val rev = resourceRaw.reversed()
                    val clean = rev.replace(Regex("[^A-Za-z0-9+/=]"), "")
                    val decoded = try {
                        String(android.util.Base64.decode(clean, android.util.Base64.DEFAULT))
                    } catch (e: Exception) { "" }

                    if (decoded.isNotBlank()) {
                        Log.d(TAG, "Watch link [$label] -> $decoded")
                        loadExtractor(decoded, data, subtitleCallback, callback)
                    }
                }
            }

            // -------------------- Download Links (px9) --------------------
            val pxRegex = Regex("""var\s+_m\s*=\s*\{\s*"r"\s*:\s*"([^"]+)"""")
            val pxMr = pxRegex.find(html)?.groupValues?.get(1)

            if (!pxMr.isNullOrBlank()) {
                try {
                    val secretBytes = android.util.Base64.decode(pxMr, android.util.Base64.DEFAULT)

                    val pRegex = Regex("""var\s+_p\d+\s*=\s*\[(.*?)\];""", RegexOption.DOT_MATCHES_ALL)
                    val pMatches = pRegex.findAll(html)

                    var idx = 0
                    for (pm in pMatches) {
                        val items = Regex("\"([^\"]+)\"").findAll(pm.groupValues[1]).map { it.groupValues[1] }.toList()
                        val sb = StringBuilder()
                        for (chunk in items) {
                            val hex = chunk.replace(Regex("[^0-9a-fA-F]"), "")
                            if (hex.isNotBlank()) {
                                val dataBytes = hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
                                val out = dataBytes.mapIndexed { i, b ->
                                    (b.toInt() xor secretBytes[i % secretBytes.size].toInt()).toByte()
                                }
                                sb.append(String(out.toByteArray(), Charsets.UTF_8))
                            }
                        }
                        val link = sb.toString().trim()
                        if (link.isNotBlank()) {
                            Log.d(TAG, "Download link [p$idx] -> $link")
                            loadExtractor(link, data, subtitleCallback, callback)
                        }
                        idx++
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing px9: ${e.message}")
                }
            }

            true
        } catch (e: Exception) {
            Log.e(TAG, "loadLinks error: ${e.message}")
            false
        }
    }
