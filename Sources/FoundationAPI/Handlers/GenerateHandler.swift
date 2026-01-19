import Foundation
import Hummingbird

enum GenerateHandler {
    @available(macOS 26, *)
    static func handle(request: Request) async throws -> Response {
        let body: PromptRequest = try await ResponseHelpers.decodeRequest(PromptRequest.self, from: request)
        let output = try await TextGenerationService.generateResponse(for: body.prompt)
        return try ResponseHelpers.jsonResponse(PromptResponse(prompt: body.prompt, response: output))
    }
}
