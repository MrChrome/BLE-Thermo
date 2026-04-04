import Foundation
import Observation

// MARK: - Mysa API Client

@Observable
class MysaClient {
    static let cognitoClientId = "19efs8tgqe942atbqmot5m36t3"
    static let cognitoPoolId   = "us-east-1_GUFWfhI7g"
    static let cognitoURL = URL(string: "https://cognito-idp.us-east-1.amazonaws.com/")!
    static let mysaBaseURL = URL(string: "https://app-prod.mysa.cloud")!

    private(set) var isAuthenticated = false
    private(set) var statusMessage: String = ""

    private var idToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?

    init() {
        idToken = UserDefaults.standard.string(forKey: "mysaIdToken")
        refreshToken = UserDefaults.standard.string(forKey: "mysaRefreshToken")
        tokenExpiry = UserDefaults.standard.object(forKey: "mysaTokenExpiry") as? Date
        isAuthenticated = refreshToken != nil
        if isAuthenticated { statusMessage = "Signed in" }
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        // Step 1: InitiateAuth with USER_SRP_AUTH
        let session = CognitoSRPSession()
        let initBody: [String: Any] = [
            "AuthFlow": "USER_SRP_AUTH",
            "ClientId": Self.cognitoClientId,
            "AuthParameters": ["USERNAME": email, "SRP_A": session.srpA]
        ]

        let initData = try await cognitoPost(target: "InitiateAuth", body: initBody)
        guard let initJson = try? JSONSerialization.jsonObject(with: initData) as? [String: Any],
              let challengeName = initJson["ChallengeName"] as? String,
              challengeName == "PASSWORD_VERIFIER",
              let challengeParams = initJson["ChallengeParameters"] as? [String: Any]
        else { throw MysaError.authFailed("Unexpected response from InitiateAuth") }

        // Step 2: Compute SRP proof and respond to challenge
        let challengeResponses = try session.computeResponse(
            challengeParams: challengeParams,
            password: password,
            poolId: Self.cognitoPoolId
        )
        let respondBody: [String: Any] = [
            "ChallengeName": "PASSWORD_VERIFIER",
            "ClientId": Self.cognitoClientId,
            "ChallengeResponses": challengeResponses
        ]

        let respondData = try await cognitoPost(target: "RespondToAuthChallenge", body: respondBody)

        guard let json = try? JSONSerialization.jsonObject(with: respondData) as? [String: Any],
              let result = json["AuthenticationResult"] as? [String: Any],
              let newIdToken = result["IdToken"] as? String,
              let newRefreshToken = result["RefreshToken"] as? String,
              let expiresIn = result["ExpiresIn"] as? Int
        else { throw MysaError.authFailed("Unexpected response from auth server") }

        await MainActor.run {
            saveTokens(idToken: newIdToken, refreshToken: newRefreshToken, expiresIn: expiresIn)
        }
    }

    private func cognitoPost(target: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: Self.cognitoURL)
        request.httpMethod = "POST"
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService.\(target)", forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let rawBody = String(data: data, encoding: .utf8) ?? "<no body>"
            print("[Mysa] \(target) failed HTTP \(http.statusCode): \(rawBody)")
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let errorType = json["__type"] as? String ?? ""
            let msg = json["message"] as? String ?? json["Message"] as? String
                ?? "Cognito error (HTTP \(http.statusCode))"
            throw MysaError.authFailed(errorType.isEmpty ? msg : "\(errorType): \(msg)")
        }
        return data
    }

    func signOut() {
        idToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isAuthenticated = false
        statusMessage = ""
        UserDefaults.standard.removeObject(forKey: "mysaIdToken")
        UserDefaults.standard.removeObject(forKey: "mysaRefreshToken")
        UserDefaults.standard.removeObject(forKey: "mysaTokenExpiry")
    }

    private func refreshIfNeeded() async throws {
        guard let expiry = tokenExpiry else {
            throw MysaError.authFailed("Not authenticated")
        }
        guard Date() > expiry.addingTimeInterval(-120) else { return }

        guard let refresh = refreshToken else {
            throw MysaError.authFailed("No refresh token")
        }

        let body: [String: Any] = [
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "ClientId": Self.cognitoClientId,
            "AuthParameters": ["REFRESH_TOKEN": refresh]
        ]

        let data = try await cognitoPost(target: "InitiateAuth", body: body)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["AuthenticationResult"] as? [String: Any],
              let newIdToken = result["IdToken"] as? String,
              let expiresIn = result["ExpiresIn"] as? Int
        else { throw MysaError.authFailed("Token refresh failed") }

        let newRefresh = (result["RefreshToken"] as? String) ?? refresh
        await MainActor.run {
            saveTokens(idToken: newIdToken, refreshToken: newRefresh, expiresIn: expiresIn)
        }
    }

    private func saveTokens(idToken: String, refreshToken: String, expiresIn: Int) {
        self.idToken = idToken
        self.refreshToken = refreshToken
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        self.isAuthenticated = true
        self.statusMessage = "Signed in"
        UserDefaults.standard.set(idToken, forKey: "mysaIdToken")
        UserDefaults.standard.set(refreshToken, forKey: "mysaRefreshToken")
        UserDefaults.standard.set(self.tokenExpiry, forKey: "mysaTokenExpiry")
    }

    // MARK: - Device Fetching

    func fetchDevices() async throws -> [MysaDeviceState] {
        try await refreshIfNeeded()

        guard let token = idToken else {
            throw MysaError.authFailed("Not authenticated")
        }

        // Fetch device list (names, models) and device states in parallel
        async let devData = apiGet(path: "devices", token: token)
        async let stateData = apiGet(path: "devices/state", token: token)

        return try parseResponse(devData: try await devData, stateData: try await stateData)
    }

    private func apiGet(path: String, token: String) async throws -> Data {
        var request = URLRequest(url: Self.mysaBaseURL.appendingPathComponent(path))
        request.setValue(token, forHTTPHeaderField: "authorization")
        request.setValue("okhttp/4.11.0", forHTTPHeaderField: "user-agent")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw MysaError.apiFailed("GET /\(path) failed (HTTP \(code))")
        }
        return data
    }

    private func parseResponse(devData: Data, stateData: Data) throws -> [MysaDeviceState] {
        guard let devJson = try? JSONSerialization.jsonObject(with: devData) as? [String: Any],
              let devicesObj = devJson["DevicesObj"] as? [String: Any]
        else { throw MysaError.parseFailed("Could not parse devices list") }

        guard let stateJson = try? JSONSerialization.jsonObject(with: stateData) as? [String: Any],
              let statesObj = stateJson["DeviceStatesObj"] as? [String: Any]
        else { throw MysaError.parseFailed("Could not parse device states") }

        var results: [MysaDeviceState] = []

        for (deviceId, deviceInfo) in devicesObj {
            guard let info = deviceInfo as? [String: Any],
                  let name = info["Name"] as? String
            else { continue }

            guard let stateDict = statesObj[deviceId] as? [String: Any] else { continue }

            // Prefer CorrectedTemp (corrected/ambient), fall back to SensorTemp (raw)
            let tempC = extractValue(stateDict["CorrectedTemp"])
                     ?? extractValue(stateDict["SensorTemp"])
                     ?? 0.0
            let humidity = extractValue(stateDict["Humidity"]) ?? 0.0

            results.append(MysaDeviceState(
                id: uuidFor(deviceId),
                deviceId: deviceId,
                name: name,
                tempF: tempC * 9.0 / 5.0 + 32.0,
                humidity: humidity
            ))
        }

        return results
    }

    /// Mysa API returns values either as {"v": X, "t": timestamp} dicts or as bare numbers.
    /// A value of -1 means missing/invalid.
    private func extractValue(_ raw: Any?) -> Double? {
        let v: Any?
        if let dict = raw as? [String: Any] {
            v = dict["v"]
        } else {
            v = raw
        }
        if let d = v as? Double { return d == -1 ? nil : d }
        if let i = v as? Int    { return i == -1 ? nil : Double(i) }
        return nil
    }

    /// Derives a stable UUID from a Mysa device ID (12-char hex MAC address).
    private func uuidFor(_ deviceId: String) -> UUID {
        // Pad device ID to exactly 12 hex chars and embed in UUID: 00000000-0000-0000-0000-<deviceId>
        let hex = deviceId.padding(toLength: 12, withPad: "0", startingAt: 0)
        return UUID(uuidString: "00000000-0000-0000-0000-\(hex)") ?? UUID()
    }
}

// MARK: - Data Models

struct MysaDeviceState {
    let id: UUID
    let deviceId: String
    let name: String
    let tempF: Double
    let humidity: Double
}

enum MysaError: LocalizedError {
    case authFailed(String)
    case apiFailed(String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg):  return msg
        case .apiFailed(let msg):   return "API error: \(msg)"
        case .parseFailed(let msg): return "Parse error: \(msg)"
        }
    }
}
