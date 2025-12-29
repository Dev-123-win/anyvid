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

    @Volatile
    private var isEngineReady = false
    
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
                
                // Mark engine as ready BEFORE attempting update
                isEngineReady = true
                Log.d("MainActivity", "Native Engines Ready")
                
                // Automate Engine Update (non-blocking, engine already usable)
                try {
                    Log.d("MainActivity", "Checking for Engine Updates...")
                    YoutubeDL.getInstance().updateYoutubeDL(this@MainActivity)
                    Log.d("MainActivity", "Engine Update check complete")
                } catch (updateEx: Exception) {
                    // Update failure should not crash the app
                    Log.w("MainActivity", "Engine update failed (non-critical)", updateEx)
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Critical: Native initialization failed", e)
                // Engine will not be available, but app should still function
            }
        }
    }
    
    // Helper to ensure engine is ready before processing requests
    private suspend fun ensureEngineReady(): Boolean {
        // Wait up to 30 seconds for engine to initialize
        repeat(60) {
            if (isEngineReady) return true
            kotlinx.coroutines.delay(500)
        }
        return false
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
                // Wait for engine to be ready (prevents release mode crashes)
                if (!ensureEngineReady()) {
                    withContext(Dispatchers.Main) {
                        result.error("ENGINE_NOT_READY", "Download engine is still initializing. Please try again.", null)
                    }
                    return@launch
                }
                // =============== OPTIMIZED ANALYSIS ===============
                // Fast but keeps all necessary metadata (title, thumbnail, description, tags)
                val request = YoutubeDLRequest(url)
                
                // Skip playlist processing (single video only)
                request.addOption("--no-playlist")
                
                // Skip unnecessary network calls
                request.addOption("--no-mark-watched")
                request.addOption("--geo-bypass")
                request.addOption("--no-check-certificate")
                
                // Skip file writing (but still get metadata in memory)
                request.addOption("--no-write-thumbnail")   // Don't save thumbnail FILE
                request.addOption("--no-write-description") // Don't save description FILE
                request.addOption("--no-write-info-json")   // Don't save JSON FILE
                request.addOption("--no-write-comments")    // Skip comments
                request.addOption("--no-write-subs")        // Skip subtitles
                request.addOption("--no-write-auto-subs")   // Skip auto subs
                
                // Speed optimizations that DON'T affect metadata
                request.addOption("--ignore-errors")
                request.addOption("--no-warnings")
                request.addOption("--socket-timeout", "15")
                request.addOption("--retries", "3")
                
                val info = YoutubeDL.getInstance().getInfo(request)
                val json = JSONObject()
                json.put("type", "youtube")
                json.put("title", info.title ?: "")
                json.put("thumbnail", info.thumbnail ?: "")
                json.put("description", info.description ?: "")
                json.put("duration", info.duration)
                
                // Extract tags if available
                val tagsArray = JSONArray()
                info.tags?.forEach { tag -> tagsArray.put(tag) }
                json.put("tags", tagsArray)

                val options = JSONArray()
                val formats = info.formats
                if (formats != null) {
                    val resolutionMap = mutableMapOf<String, JSONObject>()
                    
                    for (format in formats) {
                        val height = format.height
                        if (height <= 0) continue
                        
                        val label = when {
                            height >= 2160 -> "4k"
                            height >= 1440 -> "2k"
                            height >= 1080 -> "1080p"
                            height >= 720 -> "720p"
                            height >= 480 -> "480p"
                            else -> "360p"
                        }
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
                // Wait for engine to be ready (prevents release mode crashes)
                if (!ensureEngineReady()) {
                    withContext(Dispatchers.Main) {
                        result.error("ENGINE_NOT_READY", "Download engine is still initializing. Please try again.", null)
                    }
                    return@launch
                }
                
                val downloadDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                val sanitizedTitle = title.replace(Regex("[^a-zA-Z0-9]"), "_")
                val outputExt = if (isAudio) "mp3" else "mp4"
                val outputFile = File(downloadDir, "$sanitizedTitle.$outputExt")
                
                val request = YoutubeDLRequest(url)
                request.addOption("-o", outputFile.absolutePath)
                
                // =============== MAXIMUM SPEED ARIA2C ===============
                // Use Aria2c external downloader for maximum speed
                // -x 16: Opens 16 parallel connections per server
                // -s 16: Split file into 16 parts to download simultaneously  
                // -k 5M: Larger 5MB chunks for fewer connection overhead
                // -j 5: Allow 5 concurrent downloads
                // --min-split-size=1M: Minimum split size
                // --connect-timeout=10: Connection timeout
                // --timeout=60: Download timeout
                request.addOption("--downloader", "libaria2c.so")
                request.addOption("--external-downloader-args", "aria2c:-x 16 -s 16 -k 5M -j 5 --min-split-size=1M --connect-timeout=10 --timeout=60 --max-file-not-found=5 --max-tries=5 --retry-wait=2")
                
                // Network optimizations
                request.addOption("--force-ipv4")
                request.addOption("--no-check-certificate")  // Skip SSL verification
                request.addOption("--geo-bypass")            // Bypass geo restrictions
                
                // Skip unnecessary processing during download
                request.addOption("--no-playlist")
                request.addOption("--no-warnings")
                request.addOption("--ignore-errors")
                
                // Buffer and retry settings
                request.addOption("--buffer-size", "32K")    // Larger buffer
                request.addOption("--retries", "10")
                request.addOption("--fragment-retries", "10")
                
                // Add metadata to file
                request.addOption("--add-metadata")
                
                if (isAudio) {
                    request.addOption("-f", "bestaudio")
                    request.addOption("-x")
                    request.addOption("--audio-format", "mp3")
                } else {
                    // Ensures high quality has sound by merging
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
                    methodChannel.invokeMethod("onSuccess", mapOf(
                        "path" to outputFile.absolutePath,
                        "url" to url
                    ))
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
                webView?.settings?.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    // Speed optimizations
                    blockNetworkImage = false  // We need images for thumbnails
                    loadsImagesAutomatically = true
                    cacheMode = android.webkit.WebSettings.LOAD_DEFAULT
                    userAgentString = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
                }
                
                webView?.addJavascriptInterface(object {
                    @JavascriptInterface
                    fun onAnalysisComplete(videoUrl: String?, thumbUrl: String?, caption: String?, username: String?) {
                        runOnUiThread {
                            val json = JSONObject()
                            json.put("type", "instagram")
                            json.put("url", url)
                            json.put("videoUrl", videoUrl ?: "")
                            json.put("thumbnail", thumbUrl ?: "")
                            json.put("caption", caption ?: "")
                            json.put("username", username ?: "")
                            json.put("title", "@${username ?: "instagram"} - ${(caption ?: "").take(50)}")
                            
                            if (videoUrl != null) {
                                // Trigger download immediately
                                triggerNativeDownload(videoUrl, username ?: "insta_${System.currentTimeMillis()}")
                            }
                            
                            result.success(json.toString())
                        }
                    }
                    
                    @JavascriptInterface
                    fun onExtractionComplete(videoUrl: String?, thumbUrl: String?, description: String?) {
                        // Keep backward compatibility
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
                override fun onPageFinished(view: WebView?, pageUrl: String?) {
                    // Comprehensive Instagram extraction script with multiple fallbacks
                    val script = """
                        (function() {
                            // Try multiple selectors for video URL
                            let videoUrl = null;
                            let thumbUrl = null;
                            let caption = null;
                            let username = null;
                            
                            // Video URL - Try meta tags first (fastest)
                            videoUrl = document.querySelector('meta[property="og:video"]')?.content ||
                                       document.querySelector('meta[property="og:video:url"]')?.content ||
                                       document.querySelector('meta[property="og:video:secure_url"]')?.content ||
                                       document.querySelector('video source')?.src ||
                                       document.querySelector('video')?.src;
                            
                            // Thumbnail URL
                            thumbUrl = document.querySelector('meta[property="og:image"]')?.content ||
                                       document.querySelector('video')?.poster ||
                                       document.querySelector('img[style*="object-fit"]')?.src;
                            
                            // Caption/Description (for copy feature)
                            caption = document.querySelector('meta[property="og:description"]')?.content ||
                                      document.querySelector('meta[name="description"]')?.content ||
                                      document.querySelector('h1')?.textContent ||
                                      document.querySelector('[data-testid="post-comment-root"]')?.textContent ||
                                      '';
                            
                            // Username
                            username = document.querySelector('meta[property="og:title"]')?.content?.match(/@(\w+)/)?.[1] ||
                                       document.querySelector('a[href*="/"]')?.textContent ||
                                       'instagram';
                            
                            // Clean up caption (remove excessive whitespace)
                            caption = caption.replace(/\s+/g, ' ').trim().substring(0, 2000);
                            
                            // Call the analysis complete with all data
                            InstagramExtractor.onAnalysisComplete(videoUrl, thumbUrl, caption, username);
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
        
        // Speed optimizations for DownloadManager
        request.addRequestHeader("User-Agent", "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36")
        request.addRequestHeader("Accept", "*/*")
        request.addRequestHeader("Accept-Encoding", "gzip, deflate")
        request.addRequestHeader("Connection", "keep-alive")
        
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        manager.enqueue(request)
        
        methodChannel.invokeMethod("onSuccess", mapOf(
            "path" to "System History",
            "url" to url
        ))
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
