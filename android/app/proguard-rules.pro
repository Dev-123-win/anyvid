# ============================================
# YoutubeDL, FFmpeg & Aria2c - Core Engine
# ============================================
# Old package namespace
-keep class com.yausername.youtubedl_android.** { *; }
-keep class com.yausername.ffmpeg.** { *; }
-keep class com.yausername.aria2c.** { *; }

# New package namespace (io.github.junkfood02)
-keep class io.github.junkfood02.** { *; }
-dontwarn io.github.junkfood02.**

# Flutter plugins
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.** { *; }

# ============================================
# Kotlin Coroutines - Critical for async operations
# ============================================
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ============================================
# JSON Parsing - Used in analyzeLink
# ============================================
-keepattributes *Annotation*
-keepclassmembers class * {
    @org.json.* <methods>;
}
-keep class org.json.** { *; }

# ============================================
# WebView JavaScript Interface - Instagram Scraping
# ============================================
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keep class com.suprret.streamsaver.MainActivity$* { *; }

# ============================================
# OkHttp - Network Operations
# ============================================
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-keep interface okio.** { *; }
-keep class okhttp3.internal.** { *; }
-keep class okhttp3.internal.publicsuffix.PublicSuffixDatabase { *; }
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement

# ============================================
# Google Fonts - Dynamic Font Loading
# ============================================
-keep class com.google.fonts.** { *; }
-keep class **.GoogleFonts { *; }
-dontwarn com.google.android.gms.**

# ============================================
# Google Mobile Ads
# ============================================
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ============================================
# Prevent stripping of Lambda expressions
# ============================================
-keep class kotlin.Metadata { *; }
-keepclassmembers class **$WhenMappings { <fields>; }
-keep class kotlin.reflect.jvm.internal.** { *; }

# ============================================
# General Android Safety
# ============================================
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ============================================
# Python libraries inside youtubedl
# ============================================
-keep class ** extends android.app.Application { *; }
-dontwarn android.support.**
-dontwarn androidx.**
