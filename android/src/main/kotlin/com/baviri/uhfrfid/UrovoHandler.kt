package com.baviri.uhfrfid

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

import com.ubx.usdk.RFIDSDKManager
import com.ubx.usdk.listener.InitListener
import com.ubx.usdk.rfid.aidl.IRfidCallback

/**
 * RFID handler for **Urovo DT610** (and compatible Urovo UHF devices).
 *
 * Uses the Urovo `URFIDLibrary` SDK accessed through [RFIDSDKManager].
 * The SDK initialises asynchronously via [InitListener], so [connect]
 * holds on to the Flutter [MethodChannel.Result] and resolves it in
 * the callback.
 *
 * Tag data arrives via [IRfidCallback.onInventoryTag] — one call per tag.
 * We wrap each tag into a `List<Map>` to match the Dart [UHFTag.fromMap]
 * contract used by the NewLand handler.
 */
class UrovoHandler(
    private val context: Context,
    private val mainHandler: Handler,
) : RfidHandler {

    companion object {
        private const val TAG = "UrovoHandler"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var isConnected = false

    // ── IRfidCallback ────────────────────────────────────────────────

    private val rfidCallback = object : IRfidCallback {
        override fun onInventoryTag(epc: String?, data: String?, rssi: Int) {
            if (epc.isNullOrEmpty()) return

            val tagMap = HashMap<String, Any>()
            tagMap["epc"] = epc.uppercase()
            tagMap["rssi"] = rssi
            tagMap["readCount"] = 1

            if (!data.isNullOrEmpty()) {
                tagMap["tid"] = data.uppercase()
            }

            val tagsList = arrayListOf<Map<String, Any>>(tagMap)
            Log.d(TAG, "Tag: epc=${epc.uppercase()}, rssi=$rssi")

            mainHandler.post {
                eventSink?.success(tagsList)
            }
        }

        override fun onInventoryTagEnd() {
            Log.d(TAG, "onInventoryTagEnd")
        }
    }

    // ── RfidHandler implementation ───────────────────────────────────

    override fun connect(result: MethodChannel.Result) {
        try {
            // Check if already connected
            val mgr = RFIDSDKManager.getInstance()
            if (mgr.rfidManager != null && mgr.rfidManager.isConnected) {
                isConnected = true
                result.success(true)
                return
            }

            // Async init — result is resolved inside the callback
            mgr.init(context, object : InitListener {
                override fun onStatus(status: Boolean) {
                    Log.d(TAG, "init onStatus: $status")
                    isConnected = status
                    Handler(Looper.getMainLooper()).post {
                        if (status) {
                            result.success(true)
                        } else {
                            result.error("CONNECT_FAIL", "Urovo RFID init failed", null)
                        }
                    }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Error during connect", e)
            result.error("ERROR", e.message, null)
        }
    }

    override fun disconnect(): Boolean {
        return try {
            RFIDSDKManager.getInstance().release()
            isConnected = false
            Log.d(TAG, "release() called")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error during disconnect", e)
            false
        }
    }

    override fun startScan(): Boolean {
        return try {
            val rfidManager = RFIDSDKManager.getInstance().rfidManager ?: return false
            val result = rfidManager.startInventory()
            Log.d(TAG, "startInventory result: $result")
            result == 0
        } catch (e: Exception) {
            Log.e(TAG, "Error starting scan", e)
            false
        }
    }

    override fun stopScan(): Boolean {
        return try {
            val rfidManager = RFIDSDKManager.getInstance().rfidManager ?: return false
            rfidManager.stopInventory()
            Log.d(TAG, "stopInventory called")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping scan", e)
            false
        }
    }

    override fun setPower(readPower: Int, writePower: Int) {
        try {
            val rfidManager = RFIDSDKManager.getInstance().rfidManager ?: return
            // Convert from NewLand format (500–3300) to Urovo format (0–33 dBm)
            val dBm = readPower / 100
            val result = rfidManager.setOutputPower(dBm)
            Log.d(TAG, "setOutputPower($dBm) result: $result")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting power", e)
        }
    }

    override fun registerTagListener(eventSink: EventChannel.EventSink) {
        this.eventSink = eventSink
        try {
            val rfidManager = RFIDSDKManager.getInstance().rfidManager
            rfidManager?.registerCallback(rfidCallback)
            Log.d(TAG, "Registered IRfidCallback")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register callback", e)
        }
    }

    override fun unregisterTagListener() {
        this.eventSink = null
        try {
            val rfidManager = RFIDSDKManager.getInstance().rfidManager
            rfidManager?.unregisterCallback(rfidCallback)
            Log.d(TAG, "Unregistered IRfidCallback")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister callback", e)
        }
    }

    override fun destroy() {
        try {
            val rfidManager = RFIDSDKManager.getInstance().rfidManager
            rfidManager?.unregisterCallback(rfidCallback)
        } catch (_: Exception) {}

        try {
            RFIDSDKManager.getInstance().release()
        } catch (_: Exception) {}

        isConnected = false
    }
}
