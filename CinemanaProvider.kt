2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  java.lang.ClassCastException: java.util.LinkedHashMap cannot be cast to com.cinemana.CinemanaItem
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	at com.cinemana.CinemanaProvider.getMainPage(CinemanaProvider.kt:195)
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	at com.cinemana.CinemanaProvider$getMainPage$1.invokeSuspend(Unknown Source:16)
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	at kotlin.coroutines.jvm.internal.BaseContinuationImpl.resumeWith(ContinuationImpl.kt:33)
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.DispatchedTask.run(DispatchedTask.kt:100)
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.internal.LimitedDispatcher$Worker.run(LimitedDispatcher.kt:113)
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.TaskImpl.run(Tasks.kt:89)
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler.runSafely(CoroutineScheduler.kt:586)
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.executeTask(CoroutineScheduler.kt:820)
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.runWorker(CoroutineScheduler.kt:717)
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	at kotlinx.coroutines.scheduling.CoroutineScheduler$Worker.run(CoroutineScheduler.kt:704)
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  	Suppressed: java.lang.ClassCastException: java.util.LinkedHashMap cannot be cast to com.cinemana.CinemanaItem
2025-09-05 17:19:43.635  5633-5710  System.err              com...adost.cloudstream3.prerelease  W  		... 10 more
2025-09-05 17:19:57.418 32410-441   ActivityManagerWrapper  com.mi.android.globallauncher        E  getRecentTasks: mainTaskId=13443   userId=0   baseIntent=Intent { act=android.intent.action.MAIN flag=270532608 cmp=ComponentInfo{com.lagradost.cloudstream3.prerelease/com.lagradost.cloudstream3.ui.account.AccountSelectActivity} }

