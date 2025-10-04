4739 com.lagradost.cloudstream3.prerelease/com.lagradost.cloudstream3.MainActivity focusRequests.size=1
2025-10-04 03:10:15.324  6628-6628  DecorView[MainActivity] com...adost.cloudstream3.prerelease  D  onWindowFocusChanged hasWindowFocus false
2025-10-04 03:10:15.355  6628-6628  DecorView[]             com...adost.cloudstream3.prerelease  D  onWindowFocusChanged hasWindowFocus true
2025-10-04 03:10:15.356  6628-6628  HandWritingStubImpl     com...adost.cloudstream3.prerelease  I  refreshLastKeyboardType: 1
2025-10-04 03:10:15.356  6628-6628  HandWritingStubImpl     com...adost.cloudstream3.prerelease  I  getCurrentKeyboardType: 1
2025-10-04 03:10:15.358  5239-5239  GoogleInpu...hodService com...gle.android.inputmethod.latin  I  GoogleInputMethodService.onStartInput():1346 onStartInput(EditorInfo{EditorInfo{packageName=com.lagradost.cloudstream3.prerelease, inputType=0, inputTypeString=NULL, enableLearning=false, autoCorrection=false, autoComplete=false, imeOptions=0, privateImeOptions=null, actionName=UNSPECIFIED, actionLabel=null, initialSelStart=-1, initialSelEnd=-1, initialCapsMode=0, label=null, fieldId=-1, fieldName=null, extras=Bundle[mParcelledData.dataSize=72], hintText=null, hintLocales=[]}}, false)
2025-10-04 03:10:15.789  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p0] -> ilehttps://www.medianime.com%5D+K8G2S+EP+03+SD.zip/ffire.com/file/2m60s6keo2ldls3/%5BWita
2025-10-04 03:10:15.794  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:15.794  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: Expected URL scheme 'http' or 'https' but was 'ilehttps'
2025-10-04 03:10:15.794  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: Expected URL scheme 'http' or 'https' but was 'ilehttps'
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  java.lang.IllegalArgumentException: Expected URL scheme 'http' or 'https' but was 'ilehttps'
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.internal.CommonHttpUrl.commonParse$okhttp(-HttpUrlCommon.kt:682)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.HttpUrl$Builder.parse$okhttp(HttpUrl.kt:444)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.internal.CommonHttpUrl.commonToHttpUrl$okhttp(-HttpUrlCommon.kt:895)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.HttpUrl$Companion.get(HttpUrl.kt:452)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.Request$Builder.url(Request.kt:188)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.RequestsKt.requestCreator(Requests.kt:57)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.custom$suspendImpl(Requests.kt:136)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.custom(Unknown Source:0)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.get(Requests.kt:175)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.get$default(Requests.kt:161)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.Mediafire.getUrl$suspendImpl(Mediafire.kt:22)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.Mediafire.getUrl(Unknown Source:0)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.utils.ExtractorApiKt.loadExtractor(ExtractorApi.kt:877)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.witanime.WitAnime.loadLinks(WitanimeProvider.kt:254)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.witanime.WitAnime$loadLinks$1.invokeSuspend(Unknown Source:18)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:100)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.internal.LimitedDispatcher$Worker.run(LimitedDispatcher.kt:113)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.TaskImpl.run(Tasks.kt:89)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler.runSafely(CoroutineScheduler.kt:586)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.executeTask(CoroutineScheduler.kt:820)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.runWorker(CoroutineScheduler.kt:717)
2025-10-04 03:10:15.794  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.run(CoroutineScheduler.kt:704)
2025-10-04 03:10:15.794  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:15.795  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p1] -> k2rv9xjRcpload.com/file/54https://worku
2025-10-04 03:10:15.799  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:15.799  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: Expected URL scheme 'http' or 'https' but no scheme was found for k2rv9x...
2025-10-04 03:10:15.799  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: Expected URL scheme 'http' or 'https' but no scheme was found for k2rv9x...
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  java.lang.IllegalArgumentException: Expected URL scheme 'http' or 'https' but no scheme was found for k2rv9x...
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.internal.CommonHttpUrl.commonParse$okhttp(-HttpUrlCommon.kt:689)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.HttpUrl$Builder.parse$okhttp(HttpUrl.kt:444)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.internal.CommonHttpUrl.commonToHttpUrl$okhttp(-HttpUrlCommon.kt:895)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.HttpUrl$Companion.get(HttpUrl.kt:452)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.Request$Builder.url(Request.kt:188)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.RequestsKt.requestCreator(Requests.kt:57)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.custom$suspendImpl(Requests.kt:136)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.custom(Unknown Source:0)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.get(Requests.kt:175)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.get$default(Requests.kt:161)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.Odnoklassniki.getUrl$suspendImpl(OdnoklassnikiExtractor.kt:33)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.Odnoklassniki.getUrl(Unknown Source:0)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.utils.ExtractorApiKt.loadExtractor(ExtractorApi.kt:877)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.witanime.WitAnime.loadLinks(WitanimeProvider.kt:254)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.witanime.WitAnime$loadLinks$1.invokeSuspend(Unknown Source:18)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:100)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.internal.LimitedDispatcher$Worker.run(LimitedDispatcher.kt:113)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.TaskImpl.run(Tasks.kt:89)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler.runSafely(CoroutineScheduler.kt:586)
2025-10-04 03:10:15.799  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.executeTask(CoroutineScheduler.kt:820)
2025-10-04 03:10:15.800  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.runWorker(CoroutineScheduler.kt:717)
2025-10-04 03:10:15.800  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.run(CoroutineScheduler.kt:704)
2025-10-04 03:10:15.800  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:15.800  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p2] -> https://www.mp4upload.com/6khh71ulybuh
2025-10-04 03:10:16.246  6628-6707  RepoLink                com...adost.cloudstream3.prerelease  D  Loaded ExtractorLink: ExtractorLink(name=Mp4Upload, url=https://a1.mp4upload.com:183/d/x2x3lve7z3b4quuoekruyokijhihwebiy3g53krdnz2mh64yzsijcmo5rrl2f3jufubdkoxd/video.mp4, referer=https://www.mp4upload.com/6khh71ulybuh, type=VIDEO)
2025-10-04 03:10:16.247  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p3] -> CywAPhtt/d/dps://gofile.io
2025-10-04 03:10:16.709  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:16.709  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: No value for children
2025-10-04 03:10:16.709  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: No value for children
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  org.json.JSONException: No value for children
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at org.json.JSONObject.get(JSONObject.java:398)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at org.json.JSONObject.getJSONObject(JSONObject.java:618)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.megix.Gofile.getUrl(Extractors.kt:841)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.megix.Gofile$getUrl$1.invokeSuspend(Unknown Source:18)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:100)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.internal.LimitedDispatcher$Worker.run(LimitedDispatcher.kt:113)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.TaskImpl.run(Tasks.kt:89)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler.runSafely(CoroutineScheduler.kt:586)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.executeTask(CoroutineScheduler.kt:820)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.runWorker(CoroutineScheduler.kt:717)
2025-10-04 03:10:16.709  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.run(CoroutineScheduler.kt:704)
2025-10-04 03:10:16.710  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:16.711  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p4] -> D.zip/file
2025-10-04 03:10:16.714  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p5] -> pload.com/file/rHaaNe7Y4U6https://worku
2025-10-04 03:10:16.720  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:16.720  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: Expected URL scheme 'http' or 'https' but no scheme was found for pload....
2025-10-04 03:10:16.720  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: Expected URL scheme 'http' or 'https' but no scheme was found for pload....
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  java.lang.IllegalArgumentException: Expected URL scheme 'http' or 'https' but no scheme was found for pload....
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.internal.CommonHttpUrl.commonParse$okhttp(-HttpUrlCommon.kt:689)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.HttpUrl$Builder.parse$okhttp(HttpUrl.kt:444)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.internal.CommonHttpUrl.commonToHttpUrl$okhttp(-HttpUrlCommon.kt:895)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.HttpUrl$Companion.get(HttpUrl.kt:452)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.Request$Builder.url(Request.kt:188)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.RequestsKt.requestCreator(Requests.kt:57)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.custom$suspendImpl(Requests.kt:136)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.custom(Unknown Source:0)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.get(Requests.kt:175)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.get$default(Requests.kt:161)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.Odnoklassniki.getUrl$suspendImpl(OdnoklassnikiExtractor.kt:33)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.Odnoklassniki.getUrl(Unknown Source:0)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.utils.ExtractorApiKt.loadExtractor(ExtractorApi.kt:877)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.witanime.WitAnime.loadLinks(WitanimeProvider.kt:254)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.witanime.WitAnime$loadLinks$1.invokeSuspend(Unknown Source:18)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:100)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.internal.LimitedDispatcher$Worker.run(LimitedDispatcher.kt:113)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.TaskImpl.run(Tasks.kt:89)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler.runSafely(CoroutineScheduler.kt:586)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.executeTask(CoroutineScheduler.kt:820)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.runWorker(CoroutineScheduler.kt:717)
2025-10-04 03:10:16.720  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.run(CoroutineScheduler.kt:704)
2025-10-04 03:10:16.720  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:16.721  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p6] -> https://www.mp4upload.com/b7z7e31tlcew
2025-10-04 03:10:16.858  6628-6707  RepoLink                com...adost.cloudstream3.prerelease  D  Loaded ExtractorLink: ExtractorLink(name=Mp4Upload, url=https://a4.mp4upload.com:183/d/xkx3dve7z3b4quuoekrrqzk2c2vfp76evvne6so5vnbgw376jvmghbsk3v55xz7bwtc6y3su/video.mp4, referer=https://www.mp4upload.com/b7z7e31tlcew, type=VIDEO)
2025-10-04 03:10:16.859  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p7] -> /gofile.io/d/P7ACTVhttps:/
2025-10-04 03:10:16.864  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p8] -> https://www.media3nqi/%5BWitanime.com%5D+K8G2S+EP+03+FHD.zip/filefire.com/file/hxj4m56p10l
2025-10-04 03:10:16.873  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p9] -> ahttps://workupload.com/fileHTRhanNdUa/
2025-10-04 03:10:16.879  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:16.879  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: Expected URL scheme 'http' or 'https' but was 'ahttps'
2025-10-04 03:10:16.879  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: Expected URL scheme 'http' or 'https' but was 'ahttps'
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  java.lang.IllegalArgumentException: Expected URL scheme 'http' or 'https' but was 'ahttps'
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.internal.CommonHttpUrl.commonParse$okhttp(-HttpUrlCommon.kt:682)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.HttpUrl$Builder.parse$okhttp(HttpUrl.kt:444)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.internal.CommonHttpUrl.commonToHttpUrl$okhttp(-HttpUrlCommon.kt:895)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.HttpUrl$Companion.get(HttpUrl.kt:452)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at okhttp3.Request$Builder.url(Request.kt:188)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.RequestsKt.requestCreator(Requests.kt:57)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.custom$suspendImpl(Requests.kt:136)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.custom(Unknown Source:0)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.get(Requests.kt:175)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.nicehttp.Requests.get$default(Requests.kt:161)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.YourUpload.getUrl$suspendImpl(YourUpload.kt:18)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.YourUpload.getUrl(Unknown Source:0)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.utils.ExtractorApi.getUrl$suspendImpl(ExtractorApi.kt:1325)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.utils.ExtractorApi.getUrl(Unknown Source:0)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.utils.ExtractorApiKt.loadExtractor(ExtractorApi.kt:877)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.witanime.WitAnime.loadLinks(WitanimeProvider.kt:254)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.witanime.WitAnime$loadLinks$1.invokeSuspend(Unknown Source:18)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:100)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.internal.LimitedDispatcher$Worker.run(LimitedDispatcher.kt:113)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.TaskImpl.run(Tasks.kt:89)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler.runSafely(CoroutineScheduler.kt:586)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.executeTask(CoroutineScheduler.kt:820)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.runWorker(CoroutineScheduler.kt:717)
2025-10-04 03:10:16.879  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.run(CoroutineScheduler.kt:704)
2025-10-04 03:10:16.879  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:16.880  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p10] -> https://hexload.com/vj3glzgwwjmf
2025-10-04 03:10:18.785  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:18.785  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: Index: 1, Size: 1
2025-10-04 03:10:18.785  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  safeApiCall: Index: 1, Size: 1
2025-10-04 03:10:18.785  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  java.lang.IndexOutOfBoundsException: Index: 1, Size: 1
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at java.util.Collections$SingletonList.get(Collections.java:5260)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.Userload.decodeVideoJs(Userload.kt:52)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.Userload.getUrl$suspendImpl(Userload.kt:96)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at com.lagradost.cloudstream3.extractors.Userload$getUrl$1.invokeSuspend(Unknown Source:15)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:100)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.internal.LimitedDispatcher$Worker.run(LimitedDispatcher.kt:113)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.TaskImpl.run(Tasks.kt:89)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler.runSafely(CoroutineScheduler.kt:586)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.executeTask(CoroutineScheduler.kt:820)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.runWorker(CoroutineScheduler.kt:717)
2025-10-04 03:10:18.789  6628-6707  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.run(CoroutineScheduler.kt:704)
2025-10-04 03:10:18.789  6628-6707  ApiError                com...adost.cloudstream3.prerelease  D  -------------------------------------------------------------------
2025-10-04 03:10:18.790  6628-6707  WitAnimeLinks           com...adost.cloudstream3.prerelease  D  Download link [p11] -> https://gofile.io/d/CZ6z5j
