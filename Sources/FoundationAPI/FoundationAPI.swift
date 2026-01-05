import Foundation
import FoundationModels
import HTTPTypes
import Hummingbird
import NIOCore

// MARK: - Errors

enum AppError: LocalizedError {
    case modelUnavailable(String)
    case invalidRequest(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return "On-device model unavailable: \(reason)"
        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }

    var openAIType: String {
        switch self {
        case .modelUnavailable, .generationFailed:
            return "server_error"
        case .invalidRequest:
            return "invalid_request_error"
        }
    }
}

// MARK: - Original API Models

struct PromptRequest: Decodable {
    let prompt: String
}

struct PromptResponse: Encodable {
    let prompt: String
    let response: String
}

// MARK: - OpenAI Completions API Models

struct OpenAICompletionRequest: Decodable {
    let model: String?
    let prompt: String
    let max_tokens: Int?
    let temperature: Double?
    let top_p: Double?
    let n: Int?
    let stream: Bool?
    let logprobs: Bool?
    let echo: Bool?
    let stop: StringOrArray?

    enum StringOrArray: Decodable {
        case string(String)
        case array([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let arrayValue = try? container.decode([String].self) {
                self = .array(arrayValue)
            } else {
                throw DecodingError.typeMismatch(
                    StringOrArray.self,
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Expected String or [String]"
                    )
                )
            }
        }

        var stopStrings: [String] {
            switch self {
            case .string(let s):
                return [s]
            case .array(let a):
                return a
            }
        }
    }
}

struct OpenAICompletionResponse: Encodable {
    let id: String
    let object: String
    let created: Int64
    let model: String
    let choices: [Choice]
    let usage: Usage

    struct Choice: Encodable {
        let text: String
        let index: Int
        let logprobs: LogProbs?
        let finish_reason: String

        init(text: String, index: Int = 0, finish_reason: String = "stop") {
            self.text = text
            self.index = index
            self.logprobs = nil
            self.finish_reason = finish_reason
        }
    }

    struct LogProbs: Encodable {
        // Empty for now, as Foundation Models doesn't provide logprobs
    }

    struct Usage: Encodable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int

        init(promptTokens: Int, completionTokens: Int) {
            self.prompt_tokens = promptTokens
            self.completion_tokens = completionTokens
            self.total_tokens = promptTokens + completionTokens
        }
    }

    init(id: String, model: String, text: String, promptTokens: Int = 0, completionTokens: Int = 0, finishReason: String = "stop") {
        self.id = id
        self.object = "text_completion"
        self.created = Int64(Date().timeIntervalSince1970)
        self.model = model
        self.choices = [Choice(text: text, finish_reason: finishReason)]
        self.usage = Usage(promptTokens: promptTokens, completionTokens: completionTokens)
    }
}

// MARK: - OpenAI Streaming Models

struct OpenAIStreamChunk: Encodable {
    let id: String
    let object: String
    let created: Int64
    let model: String
    let choices: [StreamChoice]

    struct StreamChoice: Encodable {
        let text: String
        let index: Int
        let finish_reason: String?

        init(text: String, index: Int = 0, finish_reason: String? = nil) {
            self.text = text
            self.index = index
            self.finish_reason = finish_reason
        }
    }

    init(id: String, model: String, text: String, index: Int = 0, finishReason: String? = nil) {
        self.id = id
        self.object = "text_completion"
        self.created = Int64(Date().timeIntervalSince1970)
        self.model = model
        self.choices = [StreamChoice(text: text, index: index, finish_reason: finishReason)]
    }
}

struct OpenAIErrorResponse: Encodable {
    let error: ErrorDetail

    struct ErrorDetail: Encodable {
        let message: String
        let type: String
        let code: String?

        init(message: String, type: String = "invalid_request_error", code: String? = nil) {
            self.message = message
            self.type = type
            self.code = code
        }
    }
}

// MARK: - OpenAI ID Generator

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

// MARK: - Main Application

@main
struct FoundationAPI {
    static func main() async {
        if #available(macOS 26, *) {
            do {
                try await serve()
            } catch {
                fputs("Error: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        } else {
            fputs("Foundation Models require macOS 26 or newer with Apple Intelligence enabled.\n", stderr)
            exit(1)
        }
    }

    @available(macOS 26, *)
    static func serve() async throws {
        let router = Router()

        // Health check endpoint with model availability
        router.get("health") { _, _ -> Response in
            let model = SystemLanguageModel.default
            let status: String
            let httpStatus: HTTPResponse.Status

            switch model.availability {
            case .available:
                status = "ok"
                httpStatus = .ok
            case .unavailable(.deviceNotEligible):
                status = "unavailable: device not eligible for Foundation Models"
                httpStatus = .serviceUnavailable
            case .unavailable(.appleIntelligenceNotEnabled):
                status = "unavailable: Apple Intelligence not enabled in Settings"
                httpStatus = .serviceUnavailable
            case .unavailable(.modelNotReady):
                status = "unavailable: model still downloading or not ready"
                httpStatus = .serviceUnavailable
            case .unavailable(let other):
                status = "unavailable: \(other)"
                httpStatus = .serviceUnavailable
            }

            return textResponse(status, status: httpStatus)
        }

        // Original simple generate endpoint (kept for backward compatibility)
        router.post("generate") { request, _ -> Response in
            let body: PromptRequest = try await decodeRequest(PromptRequest.self, from: request)
            let output = try await generateResponse(for: body.prompt)
            return try jsonResponse(PromptResponse(prompt: body.prompt, response: output))
        }

        // OpenAI-compatible completions endpoint
        router.post("v1/completions") { request, _ -> Response in
            try await handleCompletions(request: request)
        }

        let app = Application(
            router: router,
            configuration: .init(
            address: .hostname("127.0.0.1", port: 2929),
            reuseAddress: true
        )
)

        try await app.run()
    }

    // MARK: - OpenAI Completions Handler

    @available(macOS 26, *)
    private static func handleCompletions(request: Request) async throws -> Response {
        do {
            let body: OpenAICompletionRequest = try await decodeRequest(OpenAICompletionRequest.self, from: request)

            // Validate prompt
            guard !body.prompt.isEmpty else {
                let errorResponse = OpenAIErrorResponse(error: .init(
                    message: "prompt cannot be empty",
                    type: "invalid_request_error"
                ))
                return try jsonResponse(errorResponse, status: HTTPResponse.Status.badRequest)
            }

            // Handle n > 1 not supported
            if let n = body.n, n > 1 {
                let errorResponse = OpenAIErrorResponse(error: .init(
                    message: "Generating multiple completions (n > 1) is not currently supported",
                    type: "invalid_request_error"
                ))
                return try jsonResponse(errorResponse, status: HTTPResponse.Status.badRequest)
            }

            // Map parameters with defaults
            let maxTokens = min(body.max_tokens ?? 256, 4096)
            let temperature = max(0.0, min(body.temperature ?? 0.7, 2.0))
            let model = "auto"
            let stopStrings = body.stop?.stopStrings ?? []

            // Check if streaming is requested
            if body.stream == true {
                return try await streamCompletion(
                    prompt: body.prompt,
                    model: model,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    stopStrings: stopStrings
                )
            }

            // Non-streaming response
            let result = try await generateWithTokenCount(
                prompt: body.prompt,
                maxTokens: maxTokens,
                temperature: temperature,
                stopStrings: stopStrings
            )

            let response = OpenAICompletionResponse(
                id: OpenAIIDGenerator.generate(),
                model: model,
                text: result.text,
                promptTokens: result.promptTokens,
                completionTokens: result.completionTokens,
                finishReason: result.finishReason
            )

            return try jsonResponse(response)

        } catch let error as AppError {
            let errorResponse = OpenAIErrorResponse(error: .init(
                message: error.localizedDescription,
                type: error.openAIType
            ))
            return try jsonResponse(errorResponse, status: HTTPResponse.Status.badRequest)

        } catch is DecodingError {
            let errorResponse = OpenAIErrorResponse(error: .init(
                message: "Invalid JSON in request body",
                type: "invalid_request_error"
            ))
            return try jsonResponse(errorResponse, status: HTTPResponse.Status.badRequest)

        } catch {
            let errorResponse = OpenAIErrorResponse(error: .init(
                message: error.localizedDescription,
                type: "server_error"
            ))
            return try jsonResponse(errorResponse, status: HTTPResponse.Status.internalServerError)
        }
    }

    // MARK: - Streaming

    /// Handles streaming completion requests using Server-Sent Events (SSE)
    @available(macOS 26, *)
    private static func streamCompletion(
        prompt: String,
        model: String,
        maxTokens: Int,
        temperature: Double,
        stopStrings: [String]
    ) async throws -> Response {
        // Generate the full response first
        // Note: Foundation Models doesn't support true token-by-token streaming yet
        // This is a simulated streaming experience
        let result = try await generateWithTokenCount(
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperature,
            stopStrings: stopStrings
        )

        let completionId = OpenAIIDGenerator.generate()

        // Create streaming response body
        var headers = HTTPFields()
        headers.append(.init(name: .contentType, value: "text/event-stream"))
        headers.append(.init(name: .cacheControl, value: "no-cache"))
        headers.append(.init(name: .connection, value: "keep-alive"))

        let responseBody = ResponseBody { writer in
            // Stream in chunks (simulated streaming since Foundation Models doesn't support true token streaming)
            let chunkSize = 5 // Characters per chunk for smoother streaming
            let text = result.text

            // Stream text chunks using character indices for safe UTF-8 chunking
            var position = text.startIndex

            while position < text.endIndex {
                // Calculate the end index, ensuring we don't go past the string end
                let remainingDistance = text.distance(from: position, to: text.endIndex)
                let offset = min(chunkSize, remainingDistance)

                guard let endIndex = text.index(position, offsetBy: offset, limitedBy: text.endIndex) else {
                    // If limitedBy fails, we're at the end - use endIndex
                    break
                }

                // Safe substring using character indices (guarantees valid UTF-8)
                let chunk = String(text[position..<endIndex])

                let streamChunk = OpenAIStreamChunk(
                    id: completionId,
                    model: model,
                    text: chunk
                )

                if let jsonData = try? JSONEncoder().encode(streamChunk),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    let sseLine = "data: \(jsonString)\n\n"
                    if let buffer = sseLine.data(using: .utf8) {
                        var byteBuffer = ByteBufferAllocator().buffer(capacity: buffer.count)
                        byteBuffer.writeBytes(buffer)
                        try await writer.write(byteBuffer)
                    }
                }

                // Small delay to simulate token generation
                try await Task.sleep(nanoseconds: 30_000_000) // 30ms per chunk

                position = endIndex
            }

            // Send final chunk with finish_reason
            let finalChunk = OpenAIStreamChunk(
                id: completionId,
                model: model,
                text: "",
                finishReason: result.finishReason
            )

            if let jsonData = try? JSONEncoder().encode(finalChunk),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let sseLine = "data: \(jsonString)\n\n"
                if let buffer = sseLine.data(using: .utf8) {
                    var byteBuffer = ByteBufferAllocator().buffer(capacity: buffer.count)
                    byteBuffer.writeBytes(buffer)
                    try await writer.write(byteBuffer)
                }
            }

            // Send [DONE] marker
            let doneLine = "data: [DONE]\n\n"
            if let buffer = doneLine.data(using: .utf8) {
                var byteBuffer = ByteBufferAllocator().buffer(capacity: buffer.count)
                byteBuffer.writeBytes(buffer)
                try await writer.write(byteBuffer)
            }

            try await writer.finish(nil)
        }

        return Response(status: .ok, headers: headers, body: responseBody)
    }

    // MARK: - Model Integration

    @available(macOS 26, *)
    private static func generateResponse(
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

        // LanguageModelSession.Response is a wrapper around the output
        // For String sessions, the response value is the generated text
        // Using simplified extraction without Mirror overhead
        return extractText(from: response)
    }

    @available(macOS 26, *)
    private static func generateWithTokenCount(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        stopStrings: [String] = []
    ) async throws -> (text: String, promptTokens: Int, completionTokens: Int, finishReason: String) {
        let rawText = try await generateResponse(for: prompt, maxTokens: maxTokens, temperature: temperature)

        // Apply stop sequences if provided
        let (processedText, finishReason) = applyStopSequences(to: rawText, stopStrings: stopStrings)

        let promptTokens = estimateTokens(for: prompt)
        let completionTokens = estimateTokens(for: processedText)
        return (processedText, promptTokens, completionTokens, finishReason)
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

    private static func modelAvailabilityDescription(_ model: SystemLanguageModel) -> String {
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

    // MARK: - Token Estimation

    private static func estimateTokens(for text: String) -> Int {
        // Rough estimation: ~4 characters per token for English text
        // This is a simple approximation; actual tokenization varies
        // Future: consider a proper tokenizer (e.g., tiktoken port)
        return max(1, text.utf8.count / 4)
    }

    // MARK: - Text Extraction

    /// Extracts text from LanguageModelSession.Response
    /// The response structure may vary, so we use a lightweight approach
    private static func extractText(from value: Any) -> String {
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

    // MARK: - Helpers

    @available(macOS 26, *)
    private static func decodeRequest<T: Decodable>(_ type: T.Type, from request: Request) async throws -> T {
        var mutableRequest = request
        let buffer = try await mutableRequest.collectBody(upTo: 1_000_000)
        let data = Data(buffer.readableBytesView)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status = .ok) throws -> Response {
        let data = try JSONEncoder().encode(value)
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        var headers = HTTPFields()
        headers.append(.init(name: .contentType, value: "application/json"))
        return Response(status: status, headers: headers, body: .init(byteBuffer: buffer))
    }

    private static func textResponse(_ text: String, status: HTTPResponse.Status = .ok) -> Response {
        var buffer = ByteBufferAllocator().buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        var headers = HTTPFields()
        headers.append(.init(name: .contentType, value: "text/plain; charset=utf-8"))
        return Response(status: status, headers: headers, body: .init(byteBuffer: buffer))
    }
}
