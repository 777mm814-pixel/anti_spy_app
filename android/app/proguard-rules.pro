# ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-keepclassmembers class * { @com.google.mlkit.** <methods>; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# flutter_foreground_task
-keep class com.pravera.flutter_foreground_task.** { *; }

# flutter_screen_overlay
-keep class flutter.overlay.window.flutter_overlay_window.** { *; }
