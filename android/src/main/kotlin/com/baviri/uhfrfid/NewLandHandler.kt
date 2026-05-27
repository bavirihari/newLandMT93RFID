package com.baviri.uhfrfid

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

import com.nlscan.uhf.lib.UHFManager
import com.nlscan.uhf.lib.UHFReader
import com.nlscan.uhf.lib.UHFParams
import com.nlscan.uhf.lib.TagInfo

/**
 * RFID handler for **NewLand MT93** devices.
 *
 * This is a pure extraction of the logic that was previously inlined in
 * [RfidPlugin]. Behaviour is identical — no changes have been made to
 * the NewLand integration.
 */
class NewLandHandler(
    private val context: Context,
    private val mainHandler: Handler,
) : RfidHandler {

    companion object {
        private const val TAG = "NewLandHandler"
    }

    private var mUHFMgr: UHFManager? = null
    private var eventSink: EventChannel.EventSink? = null

    private val ACTION_UHF_RESULT_SEND = "android.intent.action.UHF_RESULT_SEND"

    private val tagInventoryListener = object : UHFManager.UHFTagInventoryListener() {
        override fun onReadingResult(tagInfos: Array<out TagInfo>?) {
            Log.d(TAG, "onReadingResult: ${tagInfos?.size ?: 0} tags")
            if (tagInfos != null && tagInfos.isNotEmpty()) {
                val tagsList = processTagInfos(tagInfos)
                if (tagsList.isNotEmpty()) {
                    mainHandler.post {
                        eventSink?.success(tagsList)
                    }
                }
            }
        }
    }

    private fun ensureManager() {
        if (mUHFMgr == null) {
            try {
                mUHFMgr = UHFManager.getInstance(context)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get UHFManager instance", e)
            }
        }
    }

    override fun connect(result: MethodChannel.Result) {
        ensureManager()
        try {
            if (mUHFMgr == null) {
                result.error("NO_HARDWARE", "UHF hardware not available on this device", null)
                return
            }
            val state = mUHFMgr?.powerOn()
            Log.d(TAG, "powerOn state: $state")

            if (state == UHFReader.READER_STATE.OK_ERR) {
                Thread.sleep(100) // brief delay for hardware init
                result.success(true)
            } else {
                result.error("CONNECT_FAIL", "PowerOn Failed with state: $state", null)
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    override fun disconnect(): Boolean {
        val state = mUHFMgr?.powerOff()
        Log.d(TAG, "powerOff state: $state")
        return state == UHFReader.READER_STATE.OK_ERR
    }

    override fun startScan(): Boolean {
        mUHFMgr?.setParam(
            UHFParams.INV_CLEAR_CACHE.KEY,
            UHFParams.INV_CLEAR_CACHE.PARAM_INV_CLEAR_CACHE,
            "1"
        )
        val state = mUHFMgr?.startTagInventory()
        Log.d(TAG, "startTagInventory state: $state")
        return state == UHFReader.READER_STATE.OK_ERR
    }

    override fun stopScan(): Boolean {
        val state = mUHFMgr?.stopTagInventory()
        Log.d(TAG, "stopTagInventory state: $state")
        return state == UHFReader.READER_STATE.OK_ERR
    }

    override fun setPower(readPower: Int, writePower: Int) {
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
            Log.d(TAG, "setPower state: $paramState")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting power", e)
        }
    }

    override fun registerTagListener(eventSink: EventChannel.EventSink) {
        this.eventSink = eventSink

        try {
            mUHFMgr?.registerTagInventoryListener(tagInventoryListener)
            Log.d(TAG, "Registered TagInventoryListener")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register TagInventoryListener", e)
        }

        try {
            val filter = IntentFilter(ACTION_UHF_RESULT_SEND)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(uhfReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                context.registerReceiver(uhfReceiver, filter)
            }
            Log.d(TAG, "Registered BroadcastReceiver")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register BroadcastReceiver", e)
        }
    }

    override fun unregisterTagListener() {
        this.eventSink = null

        try {
            mUHFMgr?.unRegisterTagInventoryListener(tagInventoryListener)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister TagInventoryListener", e)
        }

        try {
            context.unregisterReceiver(uhfReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unregister BroadcastReceiver", e)
        }
    }

    override fun destroy() {
        try {
            mUHFMgr?.unRegisterTagInventoryListener(tagInventoryListener)
        } catch (_: Exception) {}

        mUHFMgr?.powerOff()
    }

    /** Converts TagInfo array to Flutter-compatible list of maps. */
    private fun processTagInfos(tagInfos: Array<out TagInfo>): ArrayList<Map<String, Any>> {
        val tagsList = ArrayList<Map<String, Any>>()

        for (tag in tagInfos) {
            try {
                val length = tag.Epclen.toInt()
                val epcBytes = if (tag.EpcId != null && tag.EpcId.size >= length && length > 0) {
                    tag.EpcId.copyOfRange(0, length)
                } else if (tag.EpcId != null) {
                    tag.EpcId
                } else {
                    continue
                }

                val epcHex = UHFReader.bytes_Hexstr(epcBytes)
                if (epcHex.isNullOrEmpty()) continue

                val tagMap = HashMap<String, Any>()
                tagMap["epc"] = epcHex
                tagMap["rssi"] = tag.RSSI
                tagMap["readCount"] = tag.ReadCnt

                if (tag.EmbededDatalen > 0 && tag.EmbededData != null) {
                    val tidLen = tag.EmbededDatalen.toInt()
                    val tidBytes = if (tag.EmbededData.size >= tidLen) {
                        tag.EmbededData.copyOfRange(0, tidLen)
                    } else {
                        tag.EmbededData
                    }
                    val tidHex = UHFReader.bytes_Hexstr(tidBytes)
                    if (!tidHex.isNullOrEmpty()) {
                        tagMap["tid"] = tidHex
                    }
                }

                tagsList.add(tagMap)
                Log.d(TAG, "Tag: epc=$epcHex, rssi=${tag.RSSI}, count=${tag.ReadCnt}")
            } catch (e: Exception) {
                Log.e(TAG, "Error processing tag", e)
            }
        }

        return tagsList
    }

    private val uhfReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_UHF_RESULT_SEND) {
                Log.d(TAG, "onReceive via broadcast")
                val tagInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayExtra(UHFManager.EXTRA_TAG_INFO, TagInfo::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayExtra(UHFManager.EXTRA_TAG_INFO)
                }

                if (tagInfos != null && eventSink != null) {
                    val castedTags = tagInfos.filterIsInstance<TagInfo>().toTypedArray()
                    val tagsList = processTagInfos(castedTags)

                    if (tagsList.isNotEmpty()) {
                        mainHandler.post {
                            eventSink?.success(tagsList)
                        }
                    }
                }
            }
        }
    }
}
