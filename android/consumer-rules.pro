# Keep NewLand UHF SDK classes intact for JNI
-keep class com.nlscan.uhf.lib.** { *; }

# Keep the plugin class itself to avoid MethodChannel lookup issues
-keep class com.baviri.uhfrfid.** { *; }
