import Foundation
import CommonCrypto
public enum PasswordHasher {
    public static let iterations = 210_000

    private static let keyLength = 32
    private static let saltLength = 16
    public static func makeRecord(password: String, iterations: Int = iterations) -> String? {
        var salt = Data(count: saltLength)
        let generated = salt.withUnsafeMutableBytes { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, saltLength, base)
        }
        guard generated == errSecSuccess else { return nil }

        guard let derived = derive(password: password, salt: salt, iterations: iterations) else { return nil }
        return "\(salt.base64EncodedString()):\(iterations):\(derived.base64EncodedString())"
    }
    public static func verify(password: String, against record: String) -> Bool {
        let parts = record.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3,
              let salt = Data(base64Encoded: String(parts[0])),
              let iterations = Int(parts[1]),
              let expected = Data(base64Encoded: String(parts[2])),
              let derived = derive(password: password, salt: salt, iterations: iterations)
        else { return false }

        return constantTimeEquals(derived, expected)
    }

    private static func derive(password: String, salt: Data, iterations: Int) -> Data? {
        guard iterations > 0 else { return nil }
        let passwordBytes = Array(password.utf8)
        var output = Data(count: keyLength)

        let status = output.withUnsafeMutableBytes { outputBuffer -> Int32 in
            guard let outputBase = outputBuffer.bindMemory(to: UInt8.self).baseAddress else { return -1 }
            return salt.withUnsafeBytes { saltBuffer -> Int32 in
                guard let saltBase = saltBuffer.bindMemory(to: UInt8.self).baseAddress else { return -1 }
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes, passwordBytes.count,
                    saltBase, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    outputBase, keyLength
                )
            }
        }

        return status == kCCSuccess ? output : nil
    }
    private static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (a, b) in zip(lhs, rhs) { difference |= a ^ b }
        return difference == 0
    }
}
public struct AdminLockState: Equatable, Sendable {
    public private(set) var failedAttempts: Int = 0
    public private(set) var blockedUntil: Date? = nil
    static let attemptsBeforeDelay = 3
    static let baseDelay: TimeInterval = 15
    public init() {}
    public func isBlocked(now: Date = Date()) -> Bool {
        guard let blockedUntil else { return false }
        return now < blockedUntil
    }
    public func remainingBlock(now: Date = Date()) -> TimeInterval {
        guard let blockedUntil, now < blockedUntil else { return 0 }
        return blockedUntil.timeIntervalSince(now)
    }
    public mutating func recordFailure(now: Date = Date()) {
        failedAttempts += 1
        guard failedAttempts >= Self.attemptsBeforeDelay else { return }

        let overshoot = failedAttempts - Self.attemptsBeforeDelay
        let delay = Self.baseDelay * pow(2, Double(overshoot))
        blockedUntil = now.addingTimeInterval(delay)
    }
    public mutating func recordSuccess() {
        failedAttempts = 0
        blockedUntil = nil
    }
}
@Observable
@MainActor
public final class AdminLock {

    public private(set) var isUnlocked: Bool = false
    public private(set) var state = AdminLockState()
    public var isPasswordSet: Bool {
        KeychainStore.read(.adminPasswordHash) != nil
    }

    public init() {}
    public enum LockError: LocalizedError {
        case passwordTooShort(minimum: Int)
        case passwordAlreadySet
        case wrongPassword
        case tooManyAttempts(retryAfter: TimeInterval)
        case storageFailure

        public var errorDescription: String? {
            switch self {
            case .passwordTooShort(let minimum):
                return "La password deve essere di almeno \(minimum) caratteri."
            case .passwordAlreadySet:
                return "Su questa macchina la password amministratore è già impostata."
            case .wrongPassword:
                return "Password errata."
            case .tooManyAttempts(let retryAfter):
                return "Troppi tentativi. Riprova tra \(Int(retryAfter.rounded(.up))) secondi."
            case .storageFailure:
                return "Impossibile salvare la password nel portachiavi di sistema."
            }
        }
    }

    public static let minimumPasswordLength = 8
    public func setInitialPassword(_ password: String) throws {
        guard !isPasswordSet else { throw LockError.passwordAlreadySet }
        guard password.count >= Self.minimumPasswordLength else {
            throw LockError.passwordTooShort(minimum: Self.minimumPasswordLength)
        }
        guard let record = PasswordHasher.makeRecord(password: password),
              KeychainStore.save(record, for: .adminPasswordHash) else {
            throw LockError.storageFailure
        }
        isUnlocked = true
        state.recordSuccess()
    }
    public func unlock(_ password: String, now: Date = Date()) throws {
        if state.isBlocked(now: now) {
            throw LockError.tooManyAttempts(retryAfter: state.remainingBlock(now: now))
        }
        guard let record = KeychainStore.read(.adminPasswordHash),
              PasswordHasher.verify(password: password, against: record) else {
            state.recordFailure(now: now)
            throw LockError.wrongPassword
        }
        isUnlocked = true
        state.recordSuccess()
    }
    public func changePassword(current: String, new: String, now: Date = Date()) throws {
        try unlock(current, now: now)
        guard new.count >= Self.minimumPasswordLength else {
            throw LockError.passwordTooShort(minimum: Self.minimumPasswordLength)
        }
        guard let record = PasswordHasher.makeRecord(password: new),
              KeychainStore.save(record, for: .adminPasswordHash) else {
            throw LockError.storageFailure
        }
    }
    public func lock() {
        isUnlocked = false
    }
}
