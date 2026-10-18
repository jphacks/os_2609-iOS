#pragma once

#include <Arduino.h>
#if defined(ARDUINO_ARCH_RP2040)
#include <bearssl/bearssl_hash.h>
#include <bearssl/bearssl_hmac.h>
#else
#include <mbedtls/md.h>
#endif

#if __has_include("beacon_auth_secrets.h")
#include "beacon_auth_secrets.h"
#else
#error "beacon_auth_secrets.h がありません。beacon_auth_secrets.example.h をコピーして、6台の鍵を設定してください。"
#endif

// iOS の BeaconAdvertisementAuthenticator と対になる、署名付き広告フレームの生成器。
// [companyID: 2][version: 1][beaconID: 1][rollingCounter: 4][HMAC tag: 8]
// companyID と counter はリトルエンディアン。HMAC-SHA256 は version から counter
// までの 6 バイトを署名し、先頭 8 バイトだけを広告へ載せる。
namespace BeaconAdvertisementAuth {
constexpr uint16_t kCompanyIdentifier = 0xFFFF;
constexpr uint8_t kProtocolVersion = 1;
constexpr size_t kFrameLength = 16;
constexpr size_t kTagLength = 8;
constexpr uint32_t kCounterPeriodMillis = 30'000;

inline bool makeFrame(char beaconID, uint32_t rollingCounter, uint8_t frame[kFrameLength]) {
    const uint8_t *key = beaconAuthKeyFor(beaconID);
    if (key == nullptr) {
        return false;
    }

    frame[0] = static_cast<uint8_t>(kCompanyIdentifier & 0xFF);
    frame[1] = static_cast<uint8_t>(kCompanyIdentifier >> 8);
    frame[2] = kProtocolVersion;
    frame[3] = static_cast<uint8_t>(beaconID);
    frame[4] = static_cast<uint8_t>(rollingCounter & 0xFF);
    frame[5] = static_cast<uint8_t>((rollingCounter >> 8) & 0xFF);
    frame[6] = static_cast<uint8_t>((rollingCounter >> 16) & 0xFF);
    frame[7] = static_cast<uint8_t>((rollingCounter >> 24) & 0xFF);

    uint8_t fullTag[32] = {};
#if defined(ARDUINO_ARCH_RP2040)
    // Earle Philhower's RP2040 Arduino core exposes BearSSL to sketches.
    // Use SHA-256 HMAC so this stays byte-for-byte compatible with ESP32/iOS.
    br_hmac_key_context keyContext;
    br_hmac_context hmacContext;
    br_hmac_key_init(&keyContext, &br_sha256_vtable, key, 32);
    br_hmac_init(&hmacContext, &keyContext, sizeof(fullTag));
    br_hmac_update(&hmacContext, frame + 2, 6);
    if (br_hmac_out(&hmacContext, fullTag) != sizeof(fullTag)) {
        return false;
    }
#else
    const mbedtls_md_info_t *sha256 = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    if (sha256 == nullptr
        || mbedtls_md_hmac(
            sha256,
            key,
            32,
            frame + 2,
            6,
            fullTag
        ) != 0) {
        return false;
    }
#endif

    memcpy(frame + 8, fullTag, kTagLength);
    return true;
}
} // namespace BeaconAdvertisementAuth
