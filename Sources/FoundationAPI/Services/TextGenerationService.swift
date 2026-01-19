import Foundation
import FoundationModels

enum TextGenerationService {
    /// Generate text response from the on-device model
    @available(macOS 26, *)
    static func generateResponse(
        for prompt: String,
        maxTokens: Int = 256,
        temperature: Double = 0.7
    ) async throws -> String {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AppError.modelUnavailable(modelAvailabilityDescription(model))
        }

        let instructions = "You are a concise, helpful assistant. Keep replies under 200 words unless asked otherwise."
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(temperature: temperature, maximumResponseTokens: maxTokens)
        let response = try await session.respond(to: prompt, options: options)

        return TextExtraction.extractText(from: response)
    }

    /// Generate text with token count estimation
    @available(macOS 26, *)
    static func generateWithTokenCount(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        stopStrings: [String] = []
    ) async throws -> (text: String, promptTokens: Int, completionTokens: Int, finishReason: String) {
        let rawText = try await generateResponse(for: prompt, maxTokens: maxTokens, temperature: temperature)

        // Apply stop sequences if provided
        let (processedText, finishReason) = applyStopSequences(to: rawText, stopStrings: stopStrings)

        let promptTokens = TokenEstimation.estimateTokens(for: prompt)
        let completionTokens = TokenEstimation.estimateTokens(for: processedText)
        return (processedText, promptTokens, completionTokens, finishReason)
    }

    /// Get human-readable model availability description
    static func modelAvailabilityDescription(_ model: SystemLanguageModel) -> String {
        switch model.availability {
        case .unavailable(.deviceNotEligible):
            return "device not eligible for Foundation Models"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence not enabled in Settings"
        case .unavailable(.modelNotReady):
            return "model still downloading or not ready"
        case .unavailable(let other):
            return "model unavailable: \(other)"
        case .available:
            return "model available"
        }
    }

    /// Applies stop sequences to generated text, returning the truncated text and finish reason
    private static func applyStopSequences(to text: String, stopStrings: [String]) -> (text: String, finishReason: String) {
        guard !stopStrings.isEmpty else {
            return (text, "stop")
        }

        // Find the first occurrence of any stop string
        var earliestIndex: String.Index?

        for stopString in stopStrings {
            if let range = text.range(of: stopString) {
                if earliestIndex == nil || range.lowerBound < earliestIndex! {
                    earliestIndex = range.lowerBound
                }
            }
        }

        if let index = earliestIndex {
            // Truncate at the stop sequence (excluding the stop sequence itself)
            let truncated = String(text.prefix(upTo: index))
            return (truncated, "stop")
        }

        return (text, "stop")
    }
}
