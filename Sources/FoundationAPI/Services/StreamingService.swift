import Foundation
import HTTPTypes
import Hummingbird
import NIOCore

enum StreamingService {
    /// Handles streaming completion requests using Server-Sent Events (SSE)
    @available(macOS 26, *)
    static func streamCompletion(
        prompt: String,
        model: String,
        maxTokens: Int,
        temperature: Double,
        stopStrings: [String]
    ) async throws -> Response {
        // Generate the full response first
        // Note: Foundation Models doesn't support true token-by-token streaming yet
        // This is a simulated streaming experience
        let result = try await TextGenerationService.generateWithTokenCount(
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
                    // If limitedBy fails, we're at the end
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
}
