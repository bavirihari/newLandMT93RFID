package com.baviri.uhfrfid

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Strategy interface for RFID device handlers.
 *
 * Each supported device family (NewLand MT93, Urovo DT610, etc.)
 * implements this interface. The [RfidPlugin] auto-detects the device
 * at runtime and delegates all operations to the appropriate handler.
 */
interface RfidHandler {

    /**
     * Powers on / connects to the RFID module.
     *
     * [result] is passed directly because some SDKs (e.g. Urovo) initialise
     * asynchronously. The implementation MUST call [result.success],
     * [result.error], or [result.notImplemented] exactly once.
     */
    fun connect(result: MethodChannel.Result)

    /**
     * Powers off / disconnects the RFID module.
     * @return true if the module powered off successfully.
     */
    fun disconnect(): Boolean

    /**
     * Starts tag inventory (scanning).
     * @return true if scanning started successfully.
     */
    fun startScan(): Boolean

    /**
     * Stops tag inventory (scanning).
     * @return true if scanning stopped successfully.
     */
    fun stopScan(): Boolean

    /**
     * Sets antenna power for read and write operations.
     *
     * Values are in the NewLand format: 500–3300 (i.e. 5–33 dBm × 100).
     * Implementations that use a different scale (e.g. Urovo uses plain dBm)
     * must convert internally.
     */
    fun setPower(readPower: Int, writePower: Int)

    /**
     * Registers the Flutter [EventChannel.EventSink] to receive tag data.
     * Called when the Dart side starts listening to [onTagsRead].
     */
    fun registerTagListener(eventSink: EventChannel.EventSink)

    /**
     * Unregisters the tag listener. Called when the Dart side cancels the stream.
     */
    fun unregisterTagListener()

    /**
     * Releases all resources. Called when the Flutter engine detaches.
     */
    fun destroy()
}
