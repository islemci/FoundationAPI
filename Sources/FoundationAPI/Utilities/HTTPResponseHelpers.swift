import Foundation
import HTTPTypes
import Hummingbird
import NIOCore

enum ResponseHelpers {
    static func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status = .ok) throws -> Response {
        let data = try JSONEncoder().encode(value)
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        var headers = HTTPFields()
        headers.append(.init(name: .contentType, value: "application/json"))
        return Response(status: status, headers: headers, body: .init(byteBuffer: buffer))
    }

    static func textResponse(_ text: String, status: HTTPResponse.Status = .ok) -> Response {
        var buffer = ByteBufferAllocator().buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        var headers = HTTPFields()
        headers.append(.init(name: .contentType, value: "text/plain; charset=utf-8"))
        return Response(status: status, headers: headers, body: .init(byteBuffer: buffer))
    }

    @available(macOS 26, *)
    static func decodeRequest<T: Decodable>(_ type: T.Type, from request: Request) async throws -> T {
        var mutableRequest = request
        let buffer = try await mutableRequest.collectBody(upTo: 1_000_000)
        let data = Data(buffer.readableBytesView)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
