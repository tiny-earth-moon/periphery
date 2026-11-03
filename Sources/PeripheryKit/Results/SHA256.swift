import Foundation

/// SHA-256 (FIPS 180-4), so that SARIF fingerprints are identical on every platform without CryptoKit.
enum SHA256 {
    private static let roundConstants: [UInt32] = [
        0x428A_2F98, 0x7137_4491, 0xB5C0_FBCF, 0xE9B5_DBA5, 0x3956_C25B, 0x59F1_11F1, 0x923F_82A4, 0xAB1C_5ED5,
        0xD807_AA98, 0x1283_5B01, 0x2431_85BE, 0x550C_7DC3, 0x72BE_5D74, 0x80DE_B1FE, 0x9BDC_06A7, 0xC19B_F174,
        0xE49B_69C1, 0xEFBE_4786, 0x0FC1_9DC6, 0x240C_A1CC, 0x2DE9_2C6F, 0x4A74_84AA, 0x5CB0_A9DC, 0x76F9_88DA,
        0x983E_5152, 0xA831_C66D, 0xB003_27C8, 0xBF59_7FC7, 0xC6E0_0BF3, 0xD5A7_9147, 0x06CA_6351, 0x1429_2967,
        0x27B7_0A85, 0x2E1B_2138, 0x4D2C_6DFC, 0x5338_0D13, 0x650A_7354, 0x766A_0ABB, 0x81C2_C92E, 0x9272_2C85,
        0xA2BF_E8A1, 0xA81A_664B, 0xC24B_8B70, 0xC76C_51A3, 0xD192_E819, 0xD699_0624, 0xF40E_3585, 0x106A_A070,
        0x19A4_C116, 0x1E37_6C08, 0x2748_774C, 0x34B0_BCB5, 0x391C_0CB3, 0x4ED8_AA4A, 0x5B9C_CA4F, 0x682E_6FF3,
        0x748F_82EE, 0x78A5_636F, 0x84C8_7814, 0x8CC7_0208, 0x90BE_FFFA, 0xA450_6CEB, 0xBEF9_A3F7, 0xC671_78F2,
    ]

    static func hexDigest(of data: Data) -> String {
        var state: [UInt32] = [
            0x6A09_E667, 0xBB67_AE85, 0x3C6E_F372, 0xA54F_F53A, 0x510E_527F, 0x9B05_688C, 0x1F83_D9AB, 0x5BE0_CD19,
        ]

        var message = [UInt8](data)
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 {
            message.append(0)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }

        var schedule = [UInt32](repeating: 0, count: 64)
        for chunk in stride(from: 0, to: message.count, by: 64) {
            for index in 0 ..< 16 {
                let offset = chunk + index * 4
                schedule[index] = message[offset ..< offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
            }
            for index in 16 ..< 64 {
                let w15 = schedule[index - 15]
                let w2 = schedule[index - 2]
                let s0 = rotateRight(w15, 7) ^ rotateRight(w15, 18) ^ (w15 >> 3)
                let s1 = rotateRight(w2, 17) ^ rotateRight(w2, 19) ^ (w2 >> 10)
                schedule[index] = schedule[index - 16] &+ s0 &+ schedule[index - 7] &+ s1
            }

            var working = state
            for index in 0 ..< 64 {
                let e = working[4]
                let a = working[0]
                let s1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25)
                let choice = (e & working[5]) ^ (~e & working[6])
                let temp1 = working[7] &+ s1 &+ choice &+ roundConstants[index] &+ schedule[index]
                let s0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22)
                let majority = (a & working[1]) ^ (a & working[2]) ^ (working[1] & working[2])
                let temp2 = s0 &+ majority
                working = [temp1 &+ temp2, a, working[1], working[2], working[3] &+ temp1, e, working[5], working[6]]
            }
            for index in 0 ..< 8 {
                state[index] = state[index] &+ working[index]
            }
        }

        return state.map { String(format: "%08x", $0) }.joined()
    }

    private static func rotateRight(_ value: UInt32, _ count: UInt32) -> UInt32 {
        (value >> count) | (value << (32 - count))
    }
}
