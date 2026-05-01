package com.apnt.rfid

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import org.json.JSONObject

// Import SDK classes
import com.nlscan.uhf.lib.UHFManager
import com.nlscan.uhf.lib.UHFReader
import com.nlscan.uhf.lib.UHFParams
import com.nlscan.uhf.lib.TagInfo

/** RfidPlugin */
class RfidPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var context: Context? = null
    private var mUHFMgr: UHFManager? = null
    private var eventSink: EventChannel.EventSink? = null

    // The Action String found in InventoryFragment.java
    private val ACTION_UHF_RESULT_SEND = "android.intent.action.UHF_RESULT_SEND"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "rfid")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "rfid/scan_stream")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (mUHFMgr == null && context != null) {
            try {
                mUHFMgr = UHFManager.getInstance(context)
            } catch (e: Exception) {
                // SDK not available on this device (missing .so / not MT93)
                // mUHFMgr stays null — individual methods will return errors
            }
        }

        when (call.method) {
            "connect" -> {
                try {
                    if (mUHFMgr == null) {
                        result.error("NO_HARDWARE", "UHF hardware not available on this device", null)
                        return
                    }
                    // FIX: powerOn returns READER_STATE, not Boolean
                    val state = mUHFMgr?.powerOn()

                    if (state == UHFReader.READER_STATE.OK_ERR) {
                        Thread.sleep(100) // Stabilize hardware
                        result.success(true)
                    } else {
                        result.error("CONNECT_FAIL", "PowerOn Failed with state: $state", null)
                    }
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            }
            "disconnect" -> {
                // FIX: powerOff returns READER_STATE
                val state = mUHFMgr?.powerOff()
                result.success(state == UHFReader.READER_STATE.OK_ERR)
            }
            "startScan" -> {
                mUHFMgr?.setParam(UHFParams.INV_CLEAR_CACHE.KEY, UHFParams.INV_CLEAR_CACHE.PARAM_INV_CLEAR_CACHE, "1")
                val state = mUHFMgr?.startTagInventory()
                if (state == UHFReader.READER_STATE.OK_ERR) {
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "stopScan" -> {
                val state = mUHFMgr?.stopTagInventory()
                result.success(state == UHFReader.READER_STATE.OK_ERR)
            }
            "setPower" -> {
                val readPower = call.argument<Int>("readPower") ?: 3000
                val writePower = call.argument<Int>("writePower") ?: 3000

                try {
                    val jsItemArray = JSONArray()
                    val jsItem = JSONObject()
                    jsItem.put("antid", 1)
                    jsItem.put("readPower", readPower)
                    jsItem.put("writePower", writePower)
                    jsItemArray.put(jsItem)

                    val paramState = mUHFMgr?.setParam(
                        UHFParams.RF_ANTPOWER.KEY,
                        UHFParams.RF_ANTPOWER.PARAM_RF_ANTPOWER,
                        jsItemArray.toString()
                    )

                    if (paramState == UHFReader.READER_STATE.OK_ERR) {
                        result.success(true)
                    } else {
                        result.error("POWER_ERR", "SDK Error: $paramState", null)
                    }
                } catch (e: Exception) {
                    result.error("JSON_ERR", e.message, null)
                }
            }
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private val uhfReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_UHF_RESULT_SEND) {
                val tagInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayExtra(UHFManager.EXTRA_TAG_INFO, TagInfo::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayExtra(UHFManager.EXTRA_TAG_INFO)
                }

                if (tagInfos != null && eventSink != null) {
                    val tagsList = ArrayList<Map<String, Any>>()

                    for (parcel in tagInfos) {
                        val tag = parcel as? TagInfo ?: continue

                        // Convert bytes to Hex String using SDK utility
                        // We use a safe copyOfRange to avoid index errors
                        val length = tag.Epclen.toInt()
                        val epcBytes = if (tag.EpcId.size >= length) {
                            tag.EpcId.copyOfRange(0, length)
                        } else {
                            tag.EpcId
                        }

                        val epcHex = UHFReader.bytes_Hexstr(epcBytes)

                        val tagMap = HashMap<String, Any>()
                        tagMap["epc"] = epcHex
                        tagMap["rssi"] = tag.RSSI
                        tagMap["readCount"] = tag.ReadCnt

                        if (tag.EmbededDatalen > 0) {
                            val tidLen = tag.EmbededDatalen.toInt()
                            val tidBytes = if (tag.EmbededData.size >= tidLen) {
                                tag.EmbededData.copyOfRange(0, tidLen)
                            } else {
                                tag.EmbededData
                            }
                            tagMap["tid"] = UHFReader.bytes_Hexstr(tidBytes)
                        }

                        tagsList.add(tagMap)
                    }

                    if (tagsList.isNotEmpty()) {
                        eventSink?.success(tagsList)
                    }
                }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        val filter = IntentFilter(ACTION_UHF_RESULT_SEND)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context?.registerReceiver(uhfReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context?.registerReceiver(uhfReceiver, filter)
        }
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        try {
            context?.unregisterReceiver(uhfReceiver)
        } catch (e: Exception) {
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        mUHFMgr?.powerOff()
    }
}