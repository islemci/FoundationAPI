import Foundation

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
