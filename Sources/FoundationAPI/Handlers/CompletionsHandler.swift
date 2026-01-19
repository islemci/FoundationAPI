import Foundation
import HTTPTypes
import Hummingbird

enum CompletionsHandler {
    @available(macOS 26, *)
    static func handle(request: Request) async throws -> Response {
        do {
            let body: OpenAICompletionRequest = try await ResponseHelpers.decodeRequest(OpenAICompletionRequest.self, from: request)

            // Validate prompt
            guard !body.prompt.isEmpty else {
                let errorResponse = OpenAIErrorResponse(error: .init(
                    message: "prompt cannot be empty",
                    type: "invalid_request_error"
                ))
                return try ResponseHelpers.jsonResponse(errorResponse, status: HTTPResponse.Status.badRequest)
            }

            // Validate model (only "auto" is supported)
            await Logger.debug("Received model: \(body.model?.description ?? "nil")")
            if let model = body.model, model != "auto" {
                let errorResponse = OpenAIErrorResponse(error: .init(
                    message: "model '\(model)' is not supported. Only 'auto' is supported.",
                    type: "invalid_request_error"
                ))
                return try ResponseHelpers.jsonResponse(errorResponse, status: HTTPResponse.Status.badRequest)
            }

            // Handle n > 1 not supported
            if let n = body.n, n > 1 {
                let errorResponse = OpenAIErrorResponse(error: .init(
                    message: "Generating multiple completions (n > 1) is not currently supported",
                    type: "invalid_request_error"
                ))
                return try ResponseHelpers.jsonResponse(errorResponse, status: HTTPResponse.Status.badRequest)
            }

            // Map parameters with defaults
            let maxTokens = min(body.max_tokens ?? 256, 4096)
            let temperature = max(0.0, min(body.temperature ?? 0.7, 2.0))
            let model = "auto"
            let stopStrings = body.stop?.stopStrings ?? []

            // Check if streaming is requested
            if body.stream == true {
                return try await StreamingService.streamCompletion(
                    prompt: body.prompt,
                    model: model,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    stopStrings: stopStrings
                )
            }

            // Non-streaming response
            let result = try await TextGenerationService.generateWithTokenCount(
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

            return try ResponseHelpers.jsonResponse(response)

        } catch let error as AppError {
            let errorResponse = OpenAIErrorResponse(error: .init(
                message: error.localizedDescription,
                type: error.openAIType
            ))
            return try ResponseHelpers.jsonResponse(errorResponse, status: HTTPResponse.Status.badRequest)

        } catch is DecodingError {
            let errorResponse = OpenAIErrorResponse(error: .init(
                message: "Invalid JSON in request body",
                type: "invalid_request_error"
            ))
            return try ResponseHelpers.jsonResponse(errorResponse, status: HTTPResponse.Status.badRequest)

        } catch {
            let errorResponse = OpenAIErrorResponse(error: .init(
                message: error.localizedDescription,
                type: "server_error"
            ))
            return try ResponseHelpers.jsonResponse(errorResponse, status: HTTPResponse.Status.internalServerError)
        }
    }
}
