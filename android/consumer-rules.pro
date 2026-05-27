# Keep NewLand UHF SDK classes intact for JNI
-keep class com.nlscan.uhf.lib.** { *; }

# Keep Urovo RFID SDK classes
-keep class com.ubx.** { *; }
-keep class com.rfiddevice.** { *; }
-keep class android.device.** { *; }

# Keep the plugin class itself to avoid MethodChannel lookup issues
-keep class com.baviri.uhfrfid.** { *; }
