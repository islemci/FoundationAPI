import Foundation

enum OpenAIIDGenerator {
    private static let charset = "abcdefghijklmnopqrstuvwxyz0123456789"

    static func generate(prefix: String = "fndt-", length: Int = 16) -> String {
        #if compiler(>=6.0)
        let randomString = String((0..<length).map { _ in
            charset.randomElement()!
        })
        #else
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        let randomString = String((0..<length).map { _ in
            charset.randomElement()!
        })
        #endif
        return prefix + randomString
    }
}
