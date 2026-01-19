import Foundation

struct PromptResponse: Encodable {
    let prompt: String
    let response: String
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
