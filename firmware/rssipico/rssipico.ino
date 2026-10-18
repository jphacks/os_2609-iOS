#include <BLE.h>
#include <btstack.h>
#include "beacon_advertisement_auth.h"

#define BEACON_NAME "BeaconD"
#define BEACON_ID 'D'

#define SERVICE_UUID "12345678-1234-5678-1234-56789abcdef0"

// BLE Service
BLEService beaconService{BLEUUID(SERVICE_UUID)};
uint32_t advertisedCounter = 0;
bool hasAdvertisedCounter = false;
// gap_advertisements_set_data はバッファをコピーしないため、広告の寿命中ずっと保持する。
uint8_t authenticatedAdvertisement[30] = {};

void refreshAuthenticatedAdvertisement() {
    const uint32_t counter = millis() / BeaconAdvertisementAuth::kCounterPeriodMillis;
    if (hasAdvertisedCounter && counter == advertisedCounter) {
        return;
    }

    uint8_t frame[BeaconAdvertisementAuth::kFrameLength] = {};
    if (!BeaconAdvertisementAuth::makeFrame(BEACON_ID, counter, frame)) {
        Serial.println("ERROR: Could not create authenticated BLE frame");
        return;
    }

    // flags + 16 byte HMAC frame + BeaconE でちょうど30 byte。
    // 128bit Service UUID まで広告すると31 byteを超えるため、GATTサービスは接続時だけ公開する。
    authenticatedAdvertisement[0] = 2;     // flags の長さ
    authenticatedAdvertisement[1] = 0x01;  // flags
    authenticatedAdvertisement[2] = 0x06;  // LE General Discoverable / BR-EDR 非対応
    authenticatedAdvertisement[3] = 17;    // manufacturer type + 16 byte frame
    authenticatedAdvertisement[4] = 0xFF;  // Manufacturer Specific Data
    memcpy(authenticatedAdvertisement + 5, frame, sizeof(frame));
    authenticatedAdvertisement[21] = 8;    // local-name type + "BeaconE"
    authenticatedAdvertisement[22] = 0x09; // Complete Local Name
    memcpy(authenticatedAdvertisement + 23, BEACON_NAME, sizeof(BEACON_NAME) - 1);

    // RP2040 Arduino BLE の広告設定は非公開のため、同ライブラリが使っている
    // BTstack API で更新する。バッファはグローバルなので参照が有効なまま残る。
    gap_advertisements_set_data(
        sizeof(authenticatedAdvertisement),
        authenticatedAdvertisement
    );

    advertisedCounter = counter;
    hasAdvertisedCounter = true;
    Serial.print("Authenticated advertising started (counter=");
    Serial.print(counter);
    Serial.println(")");
}

void setup() {
    Serial.begin(115200);

    Serial.println("BLE beacon starting...");
    Serial.print("Name: ");
    Serial.println(BEACON_NAME);

    // BLE initialization
    BLE.begin(BEACON_NAME);

    // Register Service
    BLE.server()->addService(&beaconService);

    // Tools > IP/Bluetooth Stack で「IPv4 + Bluetooth」を有効にしてビルドすること。
    // Service UUID は広告に載せず、30 byte の署名付き広告を後から設定する。
    BLE.startAdvertising(false);
    refreshAuthenticatedAdvertisement();
}

void loop() {
    // 30秒ごとに署名付きカウンタを更新する
    refreshAuthenticatedAdvertisement();
    delay(250);
}
