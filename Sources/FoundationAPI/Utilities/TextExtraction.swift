import Foundation

enum TextExtraction {
    /// Extracts text from LanguageModelSession.Response
    /// The response structure may vary, so we use a lightweight approach
    static func extractText(from value: Any) -> String {
        // Direct string case
        if let direct = value as? String {
            return direct
        }

        // LanguageModelSession.Response wraps the output
        // Try mirror for known property names first (minimal overhead)
        let mirror = Mirror(reflecting: value)
        let preferredLabels = ["output", "response", "content", "text", "generated", "value"]

        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            if preferredLabels.contains(where: { label.contains($0) }), let stringVal = child.value as? String {
                return stringVal
            }
        }

        // Fallback to first string property
        if let firstString = mirror.children.compactMap({ $0.value as? String }).first {
            return firstString
        }

        return String(describing: value)
    }
}
