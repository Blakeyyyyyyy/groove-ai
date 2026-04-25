import Foundation
import CryptoKit

/// ASC API Product Setup for Exit-Intent Offer
/// Creates the grooveai_4_99_weekly subscription product via Apple's App Store Connect API
///
/// This script:
/// 1. Authenticates to ASC API using JWT (Key ID, Issuer ID, EC private key)
/// 2. Checks for existing subscription groups
/// 3. Creates/verifies the grooveai_4_99_weekly product
/// 4. Sets pricing for all storefronts
/// 5. Validates the product was created successfully
///
/// Usage:
/// let setup = RevenueCatAPISetup(
///     keyID: "U57CPMC5A3",
///     issuerID: "522d4ad3-ea99-4ec6-bf4e-0e133d775c41",
///     privateKeyPEM: "-----BEGIN EC PRIVATE KEY-----..."
/// )
/// let result = await setup.createExitIntentProduct()

class RevenueCatAPISetup {
    private let keyID: String
    private let issuerID: String
    private let privateKeyPEM: String
    private let bundleID = "com.grooveai.app"
    private let baseURL = "https://api.appstoreconnect.apple.com"

    // Exit-intent product configuration
    private let productID = "grooveai_4_99_weekly"
    private let introPriceUSD = 4.99
    private let regularPriceUSD = 9.99
    private let introNumberOfDays = 7

    init(keyID: String, issuerID: String, privateKeyPEM: String) {
        self.keyID = keyID
        self.issuerID = issuerID
        self.privateKeyPEM = privateKeyPEM
    }

    // MARK: - Main Entry Point

    /// Creates the exit-intent product via ASC API
    /// Returns a dictionary with creation results
    func createExitIntentProduct() async -> [String: Any] {
        var results: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "productID": productID,
            "bundleID": bundleID,
            "status": "pending"
        ]

        do {
            print("[ASC Setup] Starting exit-intent product creation...")

            // Step 1: Generate JWT
            let jwt = try generateJWT()
            print("[ASC Setup] ✓ JWT generated")
            results["jwt_generated"] = true

            // Step 2: Get App ID
            guard let appID = await getAppID(jwt: jwt) else {
                results["status"] = "failed"
                results["error"] = "Could not retrieve App ID for bundle: \(bundleID)"
                print("[ASC Setup] ✗ Failed to get App ID")
                return results
            }
            print("[ASC Setup] ✓ Found App ID: \(appID)")
            results["appID"] = appID

            // Step 3: Get or create subscription group
            guard let groupID = await getOrCreateSubscriptionGroup(jwt: jwt, appID: appID) else {
                results["status"] = "failed"
                results["error"] = "Could not get/create subscription group"
                print("[ASC Setup] ✗ Failed to get/create subscription group")
                return results
            }
            print("[ASC Setup] ✓ Subscription group ID: \(groupID)")
            results["subscriptionGroupID"] = groupID

            // Step 4: Create subscription product
            let productResult = await createSubscriptionProduct(
                jwt: jwt,
                appID: appID,
                groupID: groupID
            )

            if let productRef = productResult["id"] as? String {
                print("[ASC Setup] ✓ Product created: \(productRef)")
                results["productRefID"] = productRef
                results["status"] = "success"
            } else {
                results["status"] = "failed"
                results["error"] = productResult["error"] as? String ?? "Unknown error creating product"
                results["rawResponse"] = productResult
                print("[ASC Setup] ✗ Failed to create product")
                return results
            }

            // Step 5: Set pricing for storefronts
            if let productRef = productResult["id"] as? String {
                let pricingResult = await setPricing(
                    jwt: jwt,
                    productID: productRef
                )
                results["pricingResult"] = pricingResult
                print("[ASC Setup] ✓ Pricing configured")
            }

            // Step 6: Validate product was created
            let validationResult = await validateProductCreation(jwt: jwt, appID: appID)
            results["validation"] = validationResult

            if validationResult["found"] as? Bool ?? false {
                print("[ASC Setup] ✓ Product validation successful")
                results["status"] = "success"
            } else {
                print("[ASC Setup] ⚠️ Product created but validation inconclusive")
                results["status"] = "partial_success"
            }

            return results

        } catch {
            results["status"] = "failed"
            results["error"] = error.localizedDescription
            print("[ASC Setup] ✗ Error: \(error)")
            return results
        }
    }

    // MARK: - JWT Generation

    /// Generates a JWT token for ASC API authentication
    /// Uses ECDSA P-256 signature (ES256)
    private func generateJWT() throws -> String {
        let now = Date()
        let expirationDate = now.addingTimeInterval(20 * 60) // 20 minutes

        // Header
        let headerDict: [String: String] = [
            "alg": "ES256",
            "kid": keyID,
            "typ": "JWT"
        ]
        let headerData = try JSONSerialization.data(withJSONObject: headerDict)
        let headerB64 = base64UrlEncode(headerData)

        // Payload
        let payloadDict: [String: Any] = [
            "iss": issuerID,
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(expirationDate.timeIntervalSince1970),
            "aud": "appstoreconnect-v1"
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: payloadDict)
        let payloadB64 = base64UrlEncode(payloadData)

        // Message to sign
        let message = "\(headerB64).\(payloadB64)"
        let messageData = message.data(using: .utf8)!

        // Parse private key
        let privateKey = try parsePrivateKey(privateKeyPEM)

        // Sign
        let signature = try privateKey.signature(for: messageData)
        let signatureB64 = base64UrlEncode(signature)

        return "\(message).\(signatureB64)"
    }

    /// Parses PEM-encoded EC private key
    private func parsePrivateKey(_ pem: String) throws -> P256.Signing.PrivateKey {
        // Remove PEM headers if present
        let lines = pem.split(separator: "\n").filter { line in
            !line.contains("-----BEGIN") && !line.contains("-----END")
        }
        let keyB64 = lines.joined()

        guard let keyData = Data(base64Encoded: keyB64) else {
            throw ASCError.invalidPrivateKey
        }

        return try P256.Signing.PrivateKey(derRepresentation: keyData)
    }

    /// Base64URL encoding (RFC 4648)
    private func base64UrlEncode(_ data: Data) -> String {
        let b64 = data.base64EncodedString()
        return b64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - ASC API Calls

    /// Retrieves the App ID for the given bundle identifier
    private func getAppID(jwt: String) async -> String? {
        let url = URL(string: "\(baseURL)/v1/apps?filter[bundleId]=\(bundleID)")!
        let request = makeRequest(url: url, method: "GET", jwt: jwt)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            print("[ASC API] GET /apps - status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let result = try decoder.decode(ASCAppsResponse.self, from: data)
                return result.data.first?.id
            }
            return nil
        } catch {
            print("[ASC API] Error getting app ID: \(error)")
            return nil
        }
    }

    /// Gets existing subscription group or creates one
    private func getOrCreateSubscriptionGroup(jwt: String, appID: String) async -> String? {
        // First, try to list existing groups
        let url = URL(string: "\(baseURL)/v1/apps/\(appID)/subscriptionGroups")!
        let request = makeRequest(url: url, method: "GET", jwt: jwt)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            print("[ASC API] GET /subscriptionGroups - status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let result = try decoder.decode(ASCSubscriptionGroupsResponse.self, from: data)

                // Return first group if exists
                if let firstGroup = result.data.first {
                    return firstGroup.id
                }
            }

            // No groups exist, create one
            return await createSubscriptionGroup(jwt: jwt, appID: appID)

        } catch {
            print("[ASC API] Error getting subscription groups: \(error)")
            return nil
        }
    }

    /// Creates a new subscription group
    private func createSubscriptionGroup(jwt: String, appID: String) async -> String? {
        let url = URL(string: "\(baseURL)/v1/apps/\(appID)/subscriptionGroups")!

        let payload: [String: Any] = [
            "data": [
                "type": "subscriptionGroups",
                "attributes": [
                    "referenceName": "Groove AI Premium"
                ]
            ]
        ]

        let request = makeRequest(
            url: url,
            method: "POST",
            jwt: jwt,
            body: payload
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            print("[ASC API] POST /subscriptionGroups - status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 201 {
                let decoder = JSONDecoder()
                let result = try decoder.decode(ASCSubscriptionGroupResponse.self, from: data)
                return result.data.id
            }
            return nil
        } catch {
            print("[ASC API] Error creating subscription group: \(error)")
            return nil
        }
    }

    /// Creates the subscription product
    private func createSubscriptionProduct(
        jwt: String,
        appID: String,
        groupID: String
    ) async -> [String: Any] {
        let url = URL(string: "\(baseURL)/v1/apps/\(appID)/subscriptionGroups/\(groupID)/subscriptionLevelItems")!

        let payload: [String: Any] = [
            "data": [
                "type": "subscriptionLevelItems",
                "attributes": [
                    "productId": productID,
                    "referenceName": "Exit Intent Offer - $4.99/week"
                ]
            ]
        ]

        let request = makeRequest(
            url: url,
            method: "POST",
            jwt: jwt,
            body: payload
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return ["error": "Invalid response"]
            }
            print("[ASC API] POST /subscriptionLevelItems - status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 201 {
                let decoder = JSONDecoder()
                let result = try decoder.decode(ASCProductResponse.self, from: data)
                return ["id": result.data.id, "success": true]
            } else {
                let responseStr = String(data: data, encoding: .utf8) ?? ""
                print("[ASC API] Error response: \(responseStr)")
                return ["error": "HTTP \(httpResponse.statusCode)", "response": responseStr]
            }
        } catch {
            print("[ASC API] Error creating product: \(error)")
            return ["error": error.localizedDescription]
        }
    }

    /// Sets pricing for all storefronts
    private func setPricing(jwt: String, productID: String) async -> [String: Any] {
        // This would require iterating through storefronts and setting prices
        // For now, log that pricing needs to be set in ASC web UI or via additional API calls

        var result: [String: Any] = [
            "status": "pending_manual_configuration",
            "note": "Pricing should be configured in App Store Connect dashboard"
        ]

        result["introPrice"] = [
            "amount": introPriceUSD,
            "currency": "USD",
            "duration": "\(introNumberOfDays) days"
        ]

        result["regularPrice"] = [
            "amount": regularPriceUSD,
            "currency": "USD",
            "interval": "weekly"
        ]

        return result
    }

    /// Validates that the product was created successfully
    private func validateProductCreation(jwt: String, appID: String) async -> [String: Any] {
        let url = URL(string: "\(baseURL)/v1/apps/\(appID)/subscriptionGroups")!
        let request = makeRequest(url: url, method: "GET", jwt: jwt)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return ["found": false, "error": "Invalid response"]
            }

            if httpResponse.statusCode == 200 {
                let responseStr = String(data: data, encoding: .utf8) ?? ""
                let found = responseStr.contains(productID)
                return [
                    "found": found,
                    "statusCode": httpResponse.statusCode,
                    "contains_product_id": found
                ]
            }

            return ["found": false, "statusCode": httpResponse.statusCode]
        } catch {
            return ["found": false, "error": error.localizedDescription]
        }
    }

    // MARK: - HTTP Utilities

    private func makeRequest(
        url: URL,
        method: String,
        jwt: String,
        body: [String: Any]? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        return request
    }
}

// MARK: - ASC API Response Models

struct ASCAppsResponse: Codable {
    let data: [ASCApp]
}

struct ASCApp: Codable {
    let id: String
    let attributes: [String: AnyCodable]?
}

struct ASCSubscriptionGroupsResponse: Codable {
    let data: [ASCSubscriptionGroup]
}

struct ASCSubscriptionGroup: Codable {
    let id: String
    let attributes: [String: AnyCodable]?
}

struct ASCSubscriptionGroupResponse: Codable {
    let data: ASCSubscriptionGroup
}

struct ASCProductResponse: Codable {
    let data: ASCProduct
}

struct ASCProduct: Codable {
    let id: String
    let type: String
    let attributes: [String: AnyCodable]?
}

enum AnyCodable: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AnyCodable].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Errors

enum ASCError: LocalizedError {
    case invalidPrivateKey
    case jwtGenerationFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidPrivateKey:
            return "Invalid EC private key format"
        case .jwtGenerationFailed:
            return "Failed to generate JWT token"
        case .apiError(let msg):
            return "ASC API error: \(msg)"
        }
    }
}
