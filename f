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
        } catch (e: Exception) { "" }
    }

    return try {
        val html = app.get(data).text

        // -------------------- Watch Links (x18c) --------------------
        val zG = Regex("""var\s+_zG\s*=\s*"([^"]+)"""").find(html)?.groupValues?.get(1)
        val zH = Regex("""var\s+_zH\s*=\s*"([^"]+)"""").find(html)?.groupValues?.get(1)

        val resourceRegistry: Map<String, Any>? = try { AppUtils.parseJson(base64Decode(zG)) } catch (e: Exception) { null }
        val configRegistry: Map<String, Any>? = try { AppUtils.parseJson(base64Decode(zH)) } catch (e: Exception) { null }

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
            val resourceRaw = resourceRegistry?.get(sid)?.toString() ?: continue
            val cleanBase64 = resourceRaw.reversed().replace(Regex("[^A-Za-z0-9+/=]"), "")
            val decoded = try {
                String(android.util.Base64.decode(cleanBase64, android.util.Base64.DEFAULT))
            } catch (e: Exception) { "" }

            if (decoded.isNotBlank()) {
                Log.d(TAG, "Watch link [$label] -> $decoded")
                loadExtractor(decoded, data, subtitleCallback, callback)
            }
        }

        // -------------------- Download Links (px9) --------------------
        val pxMr = Regex("""var\s+_m\s*=\s*\{\s*"r"\s*:\s*"([^"]+)"""").find(html)?.groupValues?.get(1)
        if (!pxMr.isNullOrBlank()) {
            val secretBytes = android.util.Base64.decode(pxMr, android.util.Base64.DEFAULT)

            val sMatches = Regex("""var\s+_s\s*=\s*\[(.*?)\];""", RegexOption.DOT_MATCHES_ALL)
                .find(html)?.groupValues?.get(1)?.split(",")?.map { it.trim().replace("\"","") } ?: emptyList()

            Regex("""var\s+(_p\d+)\s*=\s*\[(.*?)\];""", RegexOption.DOT_MATCHES_ALL)
                .findAll(html).forEachIndexed { idx, pm ->
                    val chunks = Regex("\"([^\"]+)\"").findAll(pm.groupValues[2]).map { it.groupValues[1] }.toList()
                    val seqRaw = sMatches.getOrNull(idx) ?: ""
                    val seq: List<Int> = try { AppUtils.parseJson(seqRaw) } catch (e: Exception) { chunks.indices.toList() }

                    val decryptedChunks = chunks.map { chunk ->
                        val hex = chunk.replace(Regex("[^0-9a-fA-F]"), "")
                        if (hex.isBlank()) return@map ""
                        val bytes = hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
                        bytes.mapIndexed { i, b -> (b.toInt() xor secretBytes[i % secretBytes.size].toInt()).toByte() }
                            .toByteArray().toString(Charsets.UTF_8)
                    }

                    val arranged = Array(decryptedChunks.size) { "" }
                    seq.forEachIndexed { i, pos ->
                        if (pos < arranged.size) arranged[pos] = decryptedChunks.getOrNull(i) ?: ""
                    }

                    val finalLink = arranged.joinToString("").trim()
                    if (finalLink.isNotBlank()) {
                        Log.d(TAG, "Download link [p$idx] -> $finalLink")
                        loadExtractor(finalLink, data, subtitleCallback, callback)
                    }
                }
        }

        true
    } catch (e: Exception) {
        Log.e(TAG, "loadLinks error: ${e.message}")
        false
    }
}
