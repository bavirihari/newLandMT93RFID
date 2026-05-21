## 2.0.0

* **BREAKING:** Changed Android package from `com.apnt.rfid` to `com.baviri.uhfrfid`
* If you reference the plugin package in ProGuard rules or native code, update to `com.baviri.uhfrfid`

## 1.0.0

* Initial stable release
* NewLand MT93 UHF RFID support
* Connect/disconnect RFID module power control
* Start/stop tag inventory scanning
* Real-time tag stream via EventChannel (EPC, RSSI, read count, TID)
* Adjustable antenna read/write power (5–33 dBm)
* Built-in SGTIN-96 to EAN-13 (GTIN-13) barcode decoder
* Dual tag delivery: AIDL listener + BroadcastReceiver fallback
* Example app included
