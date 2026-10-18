import CryptoKit
import Foundation

/// Verifies the short HMAC tag carried in a BLE Manufacturer Data frame.
///
/// Frame layout (all multi-byte fields are little endian):
/// `[companyID: 2][version: 1][beaconID: 1][rollingCounter: 4][HMAC-SHA256 tag: 8]`
/// The tag is calculated over `version...rollingCounter` with the key assigned to
/// the advertised beacon name. The counter makes stale frames observable by the
/// scanner; it is not a substitute for a challenge-response protocol.
struct BeaconAdvertisementAuthenticator {
    static let manufacturerCompanyIdentifier: UInt16 = 0xFFFF
    static let protocolVersion: UInt8 = 1
    static let frameLength = 16
    static let tagLength = 8

    private let keys: [String: SymmetricKey]

    init(keys: [String: SymmetricKey] = BeaconAuthConfiguration.keys) {
        self.keys = keys
    }

    /// Returns the authenticated counter if the frame belongs to `advertisedName`.
    func authenticatedCounter(
        advertisedName: String,
        manufacturerData: Data
    ) -> UInt32? {
        guard let key = keys[advertisedName] else { return nil }

        let bytes = [UInt8](manufacturerData)
        guard bytes.count == Self.frameLength else { return nil }

        let companyIdentifier = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        guard companyIdentifier == Self.manufacturerCompanyIdentifier,
              bytes[2] == Self.protocolVersion,
              let beaconID = advertisedName.utf8.last,
              bytes[3] == beaconID
        else {
            return nil
        }

        let signedData = Data(bytes[2...7])
        let suppliedTag = Array(bytes[8...15])
        let expectedTag = Array(
            HMAC<SHA256>.authenticationCode(for: signedData, using: key).prefix(Self.tagLength)
        )

        guard Self.constantTimeEqual(expectedTag, suppliedTag) else { return nil }

        return UInt32(bytes[4])
            | (UInt32(bytes[5]) << 8)
            | (UInt32(bytes[6]) << 16)
            | (UInt32(bytes[7]) << 24)
    }

    private static func constantTimeEqual(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        guard lhs.count == rhs.count else { return false }

        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }
}

/// Loads the per-beacon keys from the development app resource.
///
/// Create ARApp/Resources/BeaconAuthSecrets.plist from the accompanying
/// example file. Each value must be a different, cryptographically random
/// 32-byte key encoded as 64 hexadecimal characters. This project deliberately
/// tracks this file for development demonstrations; it must be untracked before
/// distributing a production app.
enum BeaconAuthConfiguration {
    static let keys: [String: SymmetricKey] = loadKeys()

    private static func loadKeys() -> [String: SymmetricKey] {
        guard let url = Bundle.main.url(forResource: "BeaconAuthSecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let entries = object as? [String: String]
        else {
            return [:]
        }

        return entries.reduce(into: [:]) { keys, entry in
            guard Location.beaconIDs.contains(entry.key),
                  let keyData = Data(hexadecimalString: entry.value),
                  keyData.count == 32
            else {
                return
            }
            keys[entry.key] = SymmetricKey(data: keyData)
        }
    }
}

private extension Data {
    init?(hexadecimalString: String) {
        let compact = hexadecimalString.filter { !$0.isWhitespace }
        guard compact.count.isMultiple(of: 2) else { return nil }

        var decoded = Data()
        var index = compact.startIndex
        while index < compact.endIndex {
            let next = compact.index(index, offsetBy: 2)
            guard let byte = UInt8(compact[index..<next], radix: 16) else { return nil }
            decoded.append(byte)
            index = next
        }
        self = decoded
    }
}
