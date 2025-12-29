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
                
                // Automate Engine Update (non-blocking)
                try {
                    Log.d("MainActivity", "Checking for Engine Updates...")
                    YoutubeDL.getInstance().updateYoutubeDL(this@MainActivity)
                    Log.d("MainActivity", "Engine Update check complete")
                } catch (updateEx: Throwable) {
                    Log.w("MainActivity", "Engine update failed (non-critical)", updateEx)
                }
            } catch (e: Throwable) {
                // Catch Throwable (Includes Error + Exception) to PREVENT CRASH
                Log.e("MainActivity", "Critical: Native initialization failed", e)
                isEngineReady = false 
            }
        }
    }
    
    // Helper to ensure engine is ready before processing requests
    private suspend fun ensureEngineReady(): Boolean {
        // Wait up to 10 seconds for engine (reduced from 30)
        repeat(20) {
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
                // ... (rest of handler remains same) ...
            }
        }
    }
    // ... analyzeLink remains same ...

    private fun downloadVideo(url: String, formatId: String, isAudio: Boolean, title: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Wait for engine to be ready
                if (!ensureEngineReady()) {
                    withContext(Dispatchers.Main) {
                        result.error("ENGINE_NOT_READY", "Download engine is still initializing.", null)
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
                // Resolve absolute path to libaria2c.so for reliability
                val aria2cPath = File(applicationInfo.nativeLibraryDir, "libaria2c.so").absolutePath
                
                request.addOption("--downloader", aria2cPath)
                request.addOption("--external-downloader-args", "aria2c:-x 16 -s 16 -k 5M -j 5 --min-split-size=1M --connect-timeout=10 --timeout=60 --max-file-not-found=5 --max-tries=5 --retry-wait=2")
                
                // ... (Rest of options remain same) ...
                
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
