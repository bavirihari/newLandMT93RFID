# ─── Newland UHF SDK (nls_uhf_lib.jar + aidc_uhf_sdk.jar) ───────────────────
# These classes are referenced by the SDK JARs but ship as part of the
# device firmware / system libraries on the MT93 Megattera Pro hardware.
# They are NOT bundled in the APK — tell R8 to ignore them at build time.

-dontwarn com.gg.reader.**
-dontwarn com.uhf.api.**
-dontwarn com.pow.api.**
-dontwarn com.nlscan.android.uhf.**
-dontwarn com.nlscan.android.scan.**
-dontwarn com.android.server.bcr.**

# Keep all SDK classes so R8 does not strip them during release builds
-keep class com.nlscan.uhf.** { *; }
-keep class com.gg.reader.** { *; }
-keep class com.uhf.api.** { *; }
-keep class com.pow.api.** { *; }
-keep class com.nlscan.android.uhf.** { *; }
-keep class com.nlscan.android.scan.** { *; }
-keep class com.android.server.bcr.** { *; }

# Flutter / general Android safety rules
-keep class io.flutter.** { *; }
-keep class androidx.** { *; }
-dontwarn io.flutter.**