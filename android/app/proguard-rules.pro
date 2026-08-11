# Sticksy — keep rules.
#
# Minification is currently DISABLED in build.gradle.kts (isMinifyEnabled = false)
# because release-only crashes were the headline bug. These rules exist so that
# turning it back on later is a one-line change rather than a debugging session.

# ---- Flutter engine & embedding ----
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ---- sqlite3 / drift (native bindings resolved reflectively) ----
-keep class com.tekartik.sqflite.** { *; }
-keep class org.sqlite.** { *; }
-keep class io.requery.android.database.** { *; }
-dontwarn org.sqlite.**

# ---- image_picker / camera intents ----
-keep class androidx.lifecycle.DefaultLifecycleObserver
-keep class androidx.core.content.FileProvider { *; }

# ---- Kotlin metadata & coroutines ----
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ---- Play Core (referenced by Flutter deferred components, unused here) ----
-dontwarn com.google.android.play.core.**

# Keep annotations and generic signatures so reflection-based plugins survive.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
