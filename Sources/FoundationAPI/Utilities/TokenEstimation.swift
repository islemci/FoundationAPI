import Foundation

enum TokenEstimation {
    /// Rough estimation: ~4 characters per token for English text
    /// This is a simple approximation; actual tokenization varies
    static func estimateTokens(for text: String) -> Int {
        return max(1, text.utf8.count / 4)
    }
}
