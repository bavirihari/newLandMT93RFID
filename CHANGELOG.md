## 0.0.1

* Initial release
* Connect and disconnect to the Newland MT93-U UHF RFID module
* Start and stop continuous tag inventory scanning
* Real-time tag data stream via `onTagsRead` (EPC, RSSI, read count, TID)
* Configurable antenna read/write power (5–33 dBm)
* Bundled Newland UHF SDK and native `.so` libraries for arm64-v8a and armeabi-v7a
* Graceful error handling for unsupported devices
* Full example app with power control and RSSI visualization
