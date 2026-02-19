import Foundation
import DeviceCheck
import CryptoKit

// MARK: - App Attest Service

class AppAttestService {

    enum AttestError: Error, LocalizedError {
        case notSupported
        case keyGenerationFailed(Error)
        case attestationFailed(Error)
        case challengeGenerationFailed
        case keyNotFound

        var errorDescription: String? {
            switch self {
            case .notSupported:
                return "App Attest is not supported on this device"
            case .keyGenerationFailed(let error):
                return "Key generation failed: \(error.localizedDescription)"
            case .attestationFailed(let error):
                return "Attestation failed: \(error.localizedDescription)"
            case .challengeGenerationFailed:
                return "Failed to generate cryptographic challenge"
            case .keyNotFound:
                return "Attestation key not found"
            }
        }
    }

    static let shared = AppAttestService()

    private let keyIdKey = "com.app.attest.keyId"
    private let attestedKey = "com.app.attest.attested"
    private var keyId: String?

    private init() {
        // Retrieve previously stored key ID
        self.keyId = UserDefaults.standard.string(forKey: keyIdKey)
    }

    // MARK: - Public API

    /// Check if App Attest is supported on this device
    func isSupported() -> Bool {
        if #available(iOS 14.0, *) {
            return DCAppAttestService.shared.isSupported
        }
        return false
    }

    /// Perform full attestation flow
    func performAttestation() async -> (success: Bool, error: String?) {
        // Check support first
        guard isSupported() else {
            return (false, "App Attest not supported (simulator or incompatible device)")
        }

        // If we already have an attested key, verify with assertion
        if let existingKeyId = keyId,
           UserDefaults.standard.bool(forKey: attestedKey) {
            do {
                let _ = try await generateAssertion(keyId: existingKeyId)
                return (true, nil)
            } catch {
                // Key might be invalid, try fresh attestation
                self.keyId = nil
                UserDefaults.standard.removeObject(forKey: keyIdKey)
                UserDefaults.standard.removeObject(forKey: attestedKey)
            }
        }

        // Generate new key and attest
        do {
            let newKeyId = try await generateKey()
            self.keyId = newKeyId

            let challenge = try generateChallenge()
            let _ = try await attestKey(keyId: newKeyId, challenge: challenge)

            // Store successful attestation
            UserDefaults.standard.set(newKeyId, forKey: keyIdKey)
            UserDefaults.standard.set(true, forKey: attestedKey)

            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    /// Generate a new attestation key
    private func generateKey() async throws -> String {
        guard #available(iOS 14.0, *) else {
            throw AttestError.notSupported
        }

        do {
            let keyId = try await DCAppAttestService.shared.generateKey()
            return keyId
        } catch {
            throw AttestError.keyGenerationFailed(error)
        }
    }

    /// Attest the key with Apple's servers
    private func attestKey(keyId: String, challenge: Data) async throws -> Data {
        guard #available(iOS 14.0, *) else {
            throw AttestError.notSupported
        }

        // Hash the challenge
        let hash = Data(SHA256.hash(data: challenge))

        do {
            let attestation = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: hash)
            return attestation
        } catch {
            throw AttestError.attestationFailed(error)
        }
    }

    /// Generate an assertion for an already-attested key
    private func generateAssertion(keyId: String) async throws -> Data {
        guard #available(iOS 14.0, *) else {
            throw AttestError.notSupported
        }

        let clientData = Data("integrity_check_\(Date().timeIntervalSince1970)".utf8)
        let hash = Data(SHA256.hash(data: clientData))

        do {
            let assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: hash)
            return assertion
        } catch {
            // If assertion fails, the key might be invalid
            throw AttestError.attestationFailed(error)
        }
    }

    /// Generate a cryptographic challenge
    private func generateChallenge() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw AttestError.challengeGenerationFailed
        }
        return Data(bytes)
    }
}
