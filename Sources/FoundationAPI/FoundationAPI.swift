import Foundation
import Hummingbird

@main
struct FoundationAPI {
    static func main() async {
        // Parse command-line arguments
        if CommandLine.arguments.contains("--debug") {
            await Logger.setDebugMode()
            await Logger.info("Debug mode enabled")
        }
        
        if #available(macOS 26, *) {
            do {
                try await serve()
            } catch {
                await Logger.error(error.localizedDescription)
                exit(1)
            }
        } else {
            await Logger.error("Foundation Models require macOS 26 or newer with Apple Intelligence enabled.")
            exit(1)
        }
    }

    @available(macOS 26, *)
    static func serve() async throws {
        let router = Router()

        // Health check endpoint with model availability
        router.get("health") { _, _ in
            HealthHandler.handle()
        }

        // Original simple generate endpoint (kept for backward compatibility)
        router.post("generate") { request, _ in
            try await GenerateHandler.handle(request: request)
        }

        // OpenAI-compatible completions endpoint (text generation)
        router.post("v1/completions") { request, _ in
            try await CompletionsHandler.handle(request: request)
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
}
