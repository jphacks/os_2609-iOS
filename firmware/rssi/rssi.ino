#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include "beacon_advertisement_auth.h"

#define BEACON_NAME "BeaconB"
#define BEACON_ID 'B'

// GATT サービスは接続確認用に残す。iPhone は UUID で識別せず、広告名と HMAC を検証する。
#define SERVICE_UUID "12345678-1234-5678-1234-56789abcdef0"

BLEAdvertising *advertising = nullptr;
uint32_t advertisedCounter = 0;
bool hasAdvertisedCounter = false;

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

    // 31 byte の広告枠に flags + 16 byte HMAC frame + BeaconF を収めるため、
    // 128bit の Service UUID は広告せず、接続時の GATT サービスとしてだけ保持する。
    BLEAdvertisementData advertisementData;
    advertisementData.setName(BEACON_NAME);
    advertisementData.setManufacturerData(
        String(reinterpret_cast<const char *>(frame), sizeof(frame))
    );

    advertising->stop();
    advertising->setAdvertisementData(advertisementData);
    advertising->setScanResponse(false);
    advertising->start();

    advertisedCounter = counter;
    hasAdvertisedCounter = true;
    Serial.printf("Authenticated advertising started (counter=%lu)\n", counter);
}

void setup() {
    Serial.begin(115200);

    Serial.println("BLE beacon starting...");
    Serial.print("Name: ");
    Serial.println(BEACON_NAME);

    // BLE初期化
    BLEDevice::init(BEACON_NAME);

    // BLE Server生成
    BLEServer *server = BLEDevice::createServer();

    // Serviceを作成
    BLEService *service = server->createService(SERVICE_UUID);
    service->start();

    advertising = BLEDevice::getAdvertising();
    refreshAuthenticatedAdvertisement();
}

void loop() {
    // 30秒ごとに署名付きカウンタを更新する
    refreshAuthenticatedAdvertisement();
    delay(250);
}
