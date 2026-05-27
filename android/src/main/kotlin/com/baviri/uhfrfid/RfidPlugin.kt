package com.baviri.uhfrfid

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin entry point for UHF RFID scanners.
 *
 * Auto-detects the device manufacturer and delegates to the appropriate
 * [RfidHandler] implementation:
 * - **Urovo** devices → [UrovoHandler]
 * - **All others** (including NewLand MT93) → [NewLandHandler]
 *
 * The Dart API is identical regardless of the underlying hardware.
 */
class RfidPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "RfidPlugin"
    }

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var context: Context? = null
    private var handler: RfidHandler? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    // ── FlutterPlugin lifecycle ──────────────────────────────────────

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "rfid")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "rfid/scan_stream")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        handler?.destroy()
        handler = null
    }

    // ── Device detection ─────────────────────────────────────────────

    private fun ensureHandler(): RfidHandler {
        if (handler == null) {
            val ctx = context
                ?: throw IllegalStateException("Context is null — plugin not attached")

            val manufacturer = Build.MANUFACTURER.lowercase()
            Log.d(TAG, "Device manufacturer: $manufacturer")

            handler = when {
                manufacturer.contains("urovo") -> {
                    Log.d(TAG, "Using UrovoHandler")
                    UrovoHandler(ctx, mainHandler)
                }
                else -> {
                    Log.d(TAG, "Using NewLandHandler (default)")
                    NewLandHandler(ctx, mainHandler)
                }
            }
        }
        return handler!!
    }

    // ── MethodCallHandler ────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        val rfid = ensureHandler()

        when (call.method) {
            "connect" -> {
                rfid.connect(result)
            }
            "disconnect" -> {
                result.success(rfid.disconnect())
            }
            "startScan" -> {
                result.success(rfid.startScan())
            }
            "stopScan" -> {
                result.success(rfid.stopScan())
            }
            "setPower" -> {
                val readPower = call.argument<Int>("readPower") ?: 3000
                val writePower = call.argument<Int>("writePower") ?: 3000
                try {
                    rfid.setPower(readPower, writePower)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("POWER_ERR", e.message, null)
                }
            }
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    // ── EventChannel.StreamHandler ───────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "onListen: EventSink registered")
        if (events != null) {
            ensureHandler().registerTagListener(events)
        }
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "onCancel: EventSink cleared")
        handler?.unregisterTagListener()
    }
}