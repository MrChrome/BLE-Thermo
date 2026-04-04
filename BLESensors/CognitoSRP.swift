import Foundation
import CryptoKit
import Security

// MARK: - Helpers

private extension Data {
    init?(hexString h: String) {
        var s = h.count.isMultiple(of: 2) ? h : "0\(h)"
        var d = Data(); d.reserveCapacity(s.count / 2)
        var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2)
            guard let b = UInt8(s[i..<j], radix: 16) else { return nil }
            d.append(b); i = j
        }
        self = d
    }
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}

// MARK: - BigUInt (minimal, for SRP 3072-bit arithmetic)

private struct BigUInt: Equatable, Comparable {
    typealias W = UInt32; typealias DW = UInt64
    var w: [W]                           // little-endian (w[0] = least significant)
    static let zero = BigUInt(w: [0])
    static let one  = BigUInt(w: [1])
    init(w words: [W]) { self.w = words; normalize() }
    init(_ v: W = 0)  { w = [v] }

    init(hex s: String) {
        var str = s.uppercased()
        while str.count > 1, str.first == "0" { str.removeFirst() }
        var words = [W]()
        var i = str.endIndex
        while i > str.startIndex {
            let n = min(8, str.distance(from: str.startIndex, to: i))
            let start = str.index(i, offsetBy: -n)
            words.append(W(str[start..<i], radix: 16) ?? 0)
            i = start
        }
        w = words.isEmpty ? [0] : words; normalize()
    }

    mutating func normalize() { while w.count > 1, w.last == 0 { w.removeLast() } }
    var isZero: Bool { w.allSatisfy { $0 == 0 } }
    var isOdd:  Bool { w[0] & 1 == 1 }

    var hexString: String {
        let top = w.reversed().drop { $0 == 0 }
        guard let f = top.first else { return "0" }
        var s = String(f, radix: 16, uppercase: true)
        for word in top.dropFirst() { s += String(format: "%08X", word) }
        return s
    }

    // pad_hex equivalent: returns bytes with no sign-bit ambiguity (matches Python's pad_hex)
    var padded: Data {
        var h = hexString
        if !h.count.isMultiple(of: 2) {
            h = "0" + h
        } else if let v = h.unicodeScalars.first?.value,
                  v == 0x38 || v == 0x39 ||
                  (v >= 0x41 && v <= 0x46) ||
                  (v >= 0x61 && v <= 0x66) {
            h = "00" + h
        }
        return Data(hexString: h) ?? Data()
    }

    static func < (l: BigUInt, r: BigUInt) -> Bool {
        if l.w.count != r.w.count { return l.w.count < r.w.count }
        for i in stride(from: l.w.count - 1, through: 0, by: -1) {
            if l.w[i] != r.w[i] { return l.w[i] < r.w[i] }
        }
        return false
    }

    static func + (l: BigUInt, r: BigUInt) -> BigUInt {
        let n = max(l.w.count, r.w.count)
        var o = [W](repeating: 0, count: n + 1); var c: DW = 0
        for i in 0..<n {
            let s = (i < l.w.count ? DW(l.w[i]) : 0) + (i < r.w.count ? DW(r.w[i]) : 0) + c
            o[i] = W(s & 0xFFFFFFFF); c = s >> 32
        }
        o[n] = W(c); return BigUInt(w: o)
    }

    static func - (l: BigUInt, r: BigUInt) -> BigUInt {  // requires l >= r
        var o = [W](repeating: 0, count: l.w.count); var b: DW = 0
        for i in 0..<l.w.count {
            let a = DW(l.w[i]), s = i < r.w.count ? DW(r.w[i]) : 0
            o[i] = W((a &- s &- b) & 0xFFFFFFFF)
            b = a < s + b ? 1 : 0
        }
        return BigUInt(w: o)
    }

    static func * (l: BigUInt, r: BigUInt) -> BigUInt {
        let m = l.w.count, n = r.w.count
        var o = [DW](repeating: 0, count: m + n)
        for i in 0..<m {
            var c: DW = 0
            for j in 0..<n {
                let p = DW(l.w[i]) * DW(r.w[j]) + o[i+j] + c
                o[i+j] = p & 0xFFFFFFFF; c = p >> 32
            }
            var k = i + n
            while c > 0 { let s = o[k] + c; o[k] = s & 0xFFFFFFFF; c = s >> 32; k += 1 }
        }
        return BigUInt(w: o.map { W($0) })
    }

    func shr(_ n: Int) -> BigUInt {
        let wo = n >> 5, bo = n & 31; guard wo < w.count else { return .zero }
        var o = [W](repeating: 0, count: w.count - wo)
        for i in 0..<o.count {
            o[i] = w[i+wo] >> bo
            if bo > 0, i+wo+1 < w.count { o[i] |= w[i+wo+1] << (32-bo) }
        }
        return BigUInt(w: o)
    }

    func shl(_ n: Int) -> BigUInt {
        let wo = n >> 5, bo = n & 31
        var o = [W](repeating: 0, count: w.count + wo + 1)
        for i in 0..<w.count {
            o[i+wo] |= w[i] << bo
            if bo > 0 { o[i+wo+1] |= w[i] >> (32-bo) }
        }
        return BigUInt(w: o)
    }

    // Knuth's Algorithm D: multi-precision division
    static func divmod(_ a: BigUInt, _ b: BigUInt) -> (q: BigUInt, r: BigUInt) {
        precondition(!b.isZero, "Division by zero")
        if a < b { return (.zero, a) }
        let n = b.w.count, m = a.w.count - n

        if n == 1 {
            var rem: DW = 0; var q = [W](repeating: 0, count: m + 1)
            for i in stride(from: m, through: 0, by: -1) {
                let x = (rem << 32) | DW(a.w[i]); q[i] = W(x / DW(b.w[0])); rem = x % DW(b.w[0])
            }
            return (BigUInt(w: q), BigUInt(w: [W(rem)]))
        }

        // D1: Normalize — shift so b's MSB is 1
        let d = b.w[n-1].leadingZeroBitCount
        var vn = b.shl(d); while vn.w.count < n { vn.w.append(0) }
        var un = a.shl(d); while un.w.count < m+n+1 { un.w.append(0) }
        var q = [W](repeating: 0, count: m + 1)

        for j in stride(from: m, through: 0, by: -1) {
            // D3: Trial quotient digit
            let u2 = (DW(un.w[j+n]) << 32) | DW(un.w[j+n-1])
            var qhat = u2 / DW(vn.w[n-1])
            var rhat = u2 % DW(vn.w[n-1])
            let unjn2: DW = j+n-2 < un.w.count ? DW(un.w[j+n-2]) : 0
            while qhat >= 0x100000000 || qhat * DW(vn.w[n-2]) > (rhat << 32) | unjn2 {
                qhat -= 1; rhat += DW(vn.w[n-1]); if rhat >= 0x100000000 { break }
            }

            // D4: Multiply and subtract
            var borrow: DW = 0
            for i in 0..<n {
                let p = qhat * DW(vn.w[i]) + borrow; let plo = p & 0xFFFFFFFF
                if DW(un.w[j+i]) >= plo {
                    un.w[j+i] = W(DW(un.w[j+i]) - plo); borrow = p >> 32
                } else {
                    un.w[j+i] = W(DW(un.w[j+i]) + 0x100000000 - plo); borrow = (p >> 32) + 1
                }
            }
            let didBorrow = DW(un.w[j+n]) < borrow
            un.w[j+n] = W((DW(un.w[j+n]) &- borrow) & 0xFFFFFFFF)

            if didBorrow {   // D6: Add back
                qhat -= 1; var c: DW = 0
                for i in 0..<n {
                    let s = DW(un.w[j+i]) + DW(vn.w[i]) + c
                    un.w[j+i] = W(s & 0xFFFFFFFF); c = s >> 32
                }
                un.w[j+n] = W((DW(un.w[j+n]) + c) & 0xFFFFFFFF)
            }
            q[j] = W(qhat & 0xFFFFFFFF)
        }
        return (BigUInt(w: q), BigUInt(w: Array(un.w[0..<n])).shr(d))
    }

    static func % (l: BigUInt, r: BigUInt) -> BigUInt { divmod(l, r).r }

    // Square-and-multiply modular exponentiation
    func power(_ exp: BigUInt, modulus mod: BigUInt) -> BigUInt {
        if mod == .one { return .zero }
        var result = BigUInt.one; var base = self % mod; var e = exp
        while !e.isZero {
            if e.isOdd { result = (result * base) % mod }
            e = e.shr(1); base = (base * base) % mod
        }
        return result
    }
}

// MARK: - SRP Constants
// Standard Cognito SRP parameters (from Amazon Cognito Identity JS)

private let srpN = BigUInt(hex:
    "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1" +
    "29024E088A67CC74020BBEA63B139B22514A08798E3404DD" +
    "EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245" +
    "E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED" +
    "EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D" +
    "C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F" +
    "83655D23DCA3AD961C62F356208552BB9ED529077096966D" +
    "670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B" +
    "E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9" +
    "DE2BCBF6955817183995497CEA956AE515D2261898FA0510" +
    "15728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64" +
    "ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7" +
    "ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6B" +
    "F12FFA06D98A0864D87602733EC86A64521F2B18177B200C" +
    "BBE117577A615D6C770988C0BAD946E208E24FA074E5AB31" +
    "43DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF"
)
private let srpG = BigUInt(hex: "2")
// k = SHA256(bytes("00" + N_HEX + "02")); precomputed for performance
private let srpK = BigUInt(hex: "538282c4354742d7cbbde2359fcf67f9f5b3a6b08791e5011b43b8a5b66d9ee6")

// MARK: - CognitoSRPSession

enum CognitoSRPError: LocalizedError {
    case missingChallenge
    case invalidChallenge
    var errorDescription: String? {
        switch self {
        case .missingChallenge: return "Missing SRP challenge parameters"
        case .invalidChallenge: return "Invalid SRP challenge (B=0 or B≡0 mod N)"
        }
    }
}

struct CognitoSRPSession {
    private let smallA: BigUInt
    let srpA: String  // hex SRP_A to send in InitiateAuth

    init() {
        // Generate 128 random bytes as the private value (< N since 2^1024 << N)
        var bytes = Data(count: 128)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 128, $0.baseAddress!) }
        let a = BigUInt(hex: bytes.hexString)
        smallA = a
        srpA = srpG.power(a, modulus: srpN).hexString
    }

    /// Given the PASSWORD_VERIFIER challenge from Cognito, compute the response.
    func computeResponse(
        challengeParams: [String: Any],
        password: String,
        poolId: String
    ) throws -> [String: Any] {
        guard
            let srpBHex     = challengeParams["SRP_B"]           as? String,
            let saltHex     = challengeParams["SALT"]            as? String,
            let secretBlock = challengeParams["SECRET_BLOCK"]    as? String,
            let userId      = challengeParams["USER_ID_FOR_SRP"] as? String
        else { throw CognitoSRPError.missingChallenge }

        let B = BigUInt(hex: srpBHex)
        guard !B.isZero, B % srpN != .zero else { throw CognitoSRPError.invalidChallenge }

        let largeA = srpG.power(smallA, modulus: srpN)

        // u = BigUInt( SHA256( pad(A) || pad(B) ) )
        let u = BigUInt(hex: sha256Hex(largeA.padded + B.padded))

        // x = BigUInt( SHA256( pad(SALT) || SHA256( poolSuffix || userId || ":" || password ) ) )
        let poolSuffix = poolId.components(separatedBy: "_").last ?? poolId
        let upHash = sha256Hex(Data((poolSuffix + userId + ":" + password).utf8))
        let x = BigUInt(hex: sha256Hex(saltPad(saltHex) + Data(hexString: upHash)!))

        // S = (B - k*g^x)^(smallA + u*x) mod N   (handle possible negative in mod N)
        let gx   = srpG.power(x, modulus: srpN)
        let kgx  = (srpK * gx) % srpN
        let bMod = B % srpN
        let base = bMod >= kgx ? bMod - kgx : srpN + bMod - kgx
        let exp  = smallA + u * x
        let S    = base.power(exp, modulus: srpN)

        // HKDF: prk = HMAC-SHA256(key=pad(u), msg=pad(S)); key = HMAC-SHA256(key=prk, msg="Caldera Derived Key\x01")[0:16]
        let prkCode = HMAC<SHA256>.authenticationCode(for: S.padded, using: SymmetricKey(data: u.padded))
        let info    = Data("Caldera Derived Key".utf8) + Data([1])
        let hkdfCode = HMAC<SHA256>.authenticationCode(for: info, using: SymmetricKey(data: Data(prkCode)))
        let hkdf    = Data(hkdfCode.prefix(16))

        // Timestamp: "EEE MMM d HH:mm:ss UTC yyyy" in en_US_POSIX / UTC
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(abbreviation: "UTC")
        df.dateFormat = "EEE MMM d HH:mm:ss 'UTC' yyyy"
        let timestamp = df.string(from: Date())

        // Signature = HMAC-SHA256(key=hkdf, msg=poolSuffix||userId||secretBlockBytes||timestamp)
        guard let secretBlockBytes = Data(base64Encoded: secretBlock) else {
            throw CognitoSRPError.missingChallenge
        }
        let msg = Data(poolSuffix.utf8) + Data(userId.utf8) + secretBlockBytes + Data(timestamp.utf8)
        let sigCode = HMAC<SHA256>.authenticationCode(for: msg, using: SymmetricKey(data: hkdf))
        let signature = Data(sigCode).base64EncodedString()

        return [
            "USERNAME":                     userId,
            "PASSWORD_CLAIM_SECRET_BLOCK":  secretBlock,
            "TIMESTAMP":                    timestamp,
            "PASSWORD_CLAIM_SIGNATURE":     signature,
        ]
    }
}

// MARK: - Private helpers

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

// pad_hex for a hex string (not BigUInt) — used for SALT from server
private func saltPad(_ saltHex: String) -> Data {
    var h = saltHex
    if !h.count.isMultiple(of: 2) { h = "0" + h }
    else if let v = h.unicodeScalars.first?.value,
            v == 0x38 || v == 0x39 ||
            (v >= 0x41 && v <= 0x46) || (v >= 0x61 && v <= 0x66) {
        h = "00" + h
    }
    return Data(hexString: h) ?? Data()
}
