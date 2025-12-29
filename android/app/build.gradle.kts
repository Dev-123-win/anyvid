plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.suprret.streamsaver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    packaging {
        jniLibs {
            useLegacyPackaging = true
            // Don't strip any native libraries from youtubedl-android
            doNotStrip.add("**/*.zip.so")
            doNotStrip.add("**/libpython*.so")
            doNotStrip.add("**/libffmpeg.so")
            doNotStrip.add("**/libaria2c.so")  // CRITICAL: Don't strip aria2c
            doNotStrip.add("**/lib*.so")       // Safety: don't strip any .so files
        }
        resources {
            excludes += listOf("META-INF/DEPENDENCIES", "META-INF/LICENSE", "META-INF/NOTICE")
        }
    }

    // CRITICAL: Prevent compression of native assets so they can be loaded
    aaptOptions {
        noCompress("so", "zip", "mp3", "tflite")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.suprret.streamsaver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = false  // Prevent resource stripping issues
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    dependencies {
        // YoutubeDL core library
        implementation("io.github.junkfood02.youtubedl-android:library:0.17.0")
        // FFmpeg for video merging
        implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.17.0")
        // Aria2c for fast parallel downloads - CRITICAL!
        implementation("io.github.junkfood02.youtubedl-android:aria2c:0.17.0")
    }
}

flutter {
    source = "../.."
}
