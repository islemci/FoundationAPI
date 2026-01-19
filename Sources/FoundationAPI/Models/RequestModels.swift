import Foundation

struct PromptRequest: Decodable {
    let prompt: String
}

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
