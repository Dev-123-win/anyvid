package com.suprret.streamsaver

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.ffmpeg.FFmpeg
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.streamsaver.engine/channel"
    private lateinit var methodChannel: MethodChannel
    private var webView: WebView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize heavy engines in background to avoid splash hang
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d("MainActivity", "Starting Native Engine Initialization...")
                YoutubeDL.getInstance().init(this@MainActivity)
                Log.d("MainActivity", "YoutubeDL Initialized")
                FFmpeg.getInstance().init(this@MainActivity)
                Log.d("MainActivity", "FFmpeg Initialized")
                Log.d("MainActivity", "Native Engines Ready")
            } catch (e: Exception) {
                Log.e("MainActivity", "Critical: Native initialization failed", e)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "analyzeLink" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        analyzeLink(url, result)
                    } else {
                        result.error("INVALID_URL", "URL is null", null)
                    }
                }
                "downloadVideo" -> {
                    val url = call.argument<String>("url")
                    val formatId = call.argument<String>("formatId")
                    val isAudio = call.argument<Boolean>("isAudio") ?: false
                    val title = call.argument<String>("title") ?: "video"
                    if (url != null && formatId != null) {
                        downloadVideo(url, formatId, isAudio, title, result)
                    } else {
                        result.error("INVALID_PARAMS", "Params are null", null)
                    }
                }
                "updateEngine" -> {
                    updateYoutubeDL(result)
                }
                "downloadInsta" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        scrapeInstagram(url, result)
                    } else {
                        result.error("INVALID_URL", "URL is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun analyzeLink(url: String, result: MethodChannel.Result) {
        if (url.contains("instagram.com")) {
            // Meta-data for Instagram is basic
            val json = JSONObject()
            json.put("type", "instagram")
            json.put("url", url)
            result.success(json.toString())
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val info = YoutubeDL.getInstance().getInfo(url)
                val json = JSONObject()
                json.put("type", "youtube")
                json.put("title", info.title)
                json.put("thumbnail", info.thumbnail)
                json.put("description", info.description)
                json.put("duration", info.duration)

                val options = JSONArray()
                val formats = info.formats
                if (formats != null) {
                    val resolutionMap = mutableMapOf<String, JSONObject>()
                    
                    for (format in formats) {
                        val height = format.height
                        if (height <= 0) continue
                        
                        val label = "${height}p"
                        val size = format.fileSize ?: 0L
                        val sizeStr = if (size > 0) "${size / 1024 / 1024}MB" else "Unknown"
                        
                        // Favor mp4 or just pick best for each resolution
                        if (!resolutionMap.containsKey(label) || (format.ext == "mp4" && resolutionMap[label]?.getString("ext") != "mp4")) {
                            val obj = JSONObject()
                            obj.put("id", format.formatId)
                            obj.put("label", label)
                            obj.put("size", sizeStr)
                            obj.put("ext", format.ext)
                            resolutionMap[label] = obj
                        }
                    }
                    
                    // Add Audio Only option
                    val bestAudio = info.formats?.filter { it.acodec != "none" && it.vcodec == "none" }?.maxByOrNull { (it.abr ?: 0f).toFloat() }
                    if (bestAudio != null) {
                        val audioObj = JSONObject()
                        audioObj.put("id", bestAudio.formatId)
                        audioObj.put("label", "Audio Only (MP3)")
                        val aSize = bestAudio.fileSize ?: 0L
                        audioObj.put("size", if (aSize > 0) "${aSize / 1024 / 1024}MB" else "Unknown")
                        audioObj.put("ext", "mp3")
                        options.put(audioObj)
                    }

                    // Sort resolutions descending
                    resolutionMap.keys.sortedByDescending { it.replace("p", "").toIntOrNull() ?: 0 }.forEach {
                        options.put(resolutionMap[it])
                    }
                }
                json.put("options", options)
                
                withContext(Dispatchers.Main) {
                    result.success(json.toString())
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("ANALYZE_ERROR", e.message, null)
                }
            }
        }
    }

    private fun downloadVideo(url: String, formatId: String, isAudio: Boolean, title: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val downloadDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                val sanitizedTitle = title.replace(Regex("[^a-zA-Z0-9]"), "_")
                val outputExt = if (isAudio) "mp3" else "mp4"
                val outputFile = File(downloadDir, "$sanitizedTitle.$outputExt")
                
                val request = YoutubeDLRequest(url)
                request.addOption("-o", outputFile.absolutePath)
                
                if (isAudio) {
                    request.addOption("-f", "bestaudio")
                    request.addOption("-x")
                    request.addOption("--audio-format", "mp3")
                } else {
                    // Ensures 1080p has sound by merging
                    request.addOption("-f", "$formatId+bestaudio/best")
                    request.addOption("--merge-output-format", "mp4")
                }

                YoutubeDL.getInstance().execute(request) { progress, eta, line ->
                    runOnUiThread {
                        methodChannel.invokeMethod("onProgress", mapOf(
                            "url" to url,
                            "progress" to progress,
                            "eta" to eta,
                            "line" to line
                        ))
                    }
                }

                withContext(Dispatchers.Main) {
                    result.success(outputFile.absolutePath)
                    methodChannel.invokeMethod("onSuccess", mapOf("path" to outputFile.absolutePath))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("DOWNLOAD_ERROR", e.message, null)
                }
            }
        }
    }

    private fun scrapeInstagram(url: String, result: MethodChannel.Result) {
        runOnUiThread {
            if (webView == null) {
                webView = WebView(this@MainActivity)
                webView?.settings?.javaScriptEnabled = true
                webView?.settings?.userAgentString = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36"
                webView?.addJavascriptInterface(object {
                    @JavascriptInterface
                    fun onExtractionComplete(videoUrl: String?, thumbUrl: String?, description: String?) {
                        runOnUiThread {
                            if (videoUrl != null) {
                                triggerNativeDownload(videoUrl, description ?: "insta_${System.currentTimeMillis()}")
                                result.success(videoUrl)
                            } else {
                                result.error("EXTRACTION_FAILED", "Could not find video URL", null)
                            }
                        }
                    }
                }, "InstagramExtractor")
            }

            webView?.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    val script = """
                        (function() {
                            const video = document.querySelector('meta[property="og:video"]')?.content;
                            const thumb = document.querySelector('meta[property="og:image"]')?.content;
                            const desc = document.querySelector('meta[property="og:description"]')?.content;
                            InstagramExtractor.onExtractionComplete(video, thumb, desc);
                        })();
                    """.trimIndent()
                    view?.evaluateJavascript(script, null)
                }
            }
            webView?.loadUrl(url)
        }
    }

    private fun triggerNativeDownload(url: String, fileName: String) {
        val request = DownloadManager.Request(Uri.parse(url))
        val sanitizedName = fileName.replace(Regex("[^a-zA-Z0-9]"), "_").take(50)
        request.setTitle("AnyVid: $sanitizedName")
        request.setDescription("Downloading Instagram Content")
        request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
        request.setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, "$sanitizedName.mp4")
        
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        manager.enqueue(request)
        
        methodChannel.invokeMethod("onSuccess", mapOf("path" to "System History"))
    }

    private fun updateYoutubeDL(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val status = YoutubeDL.getInstance().updateYoutubeDL(this@MainActivity)
                withContext(Dispatchers.Main) {
                    result.success(status?.name ?: "DONE")
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("UPDATE_ERROR", e.message, null)
                }
            }
        }
    }
}
