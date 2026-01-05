# FoundationAPI

A Swift command-line tool that talks to on-device Apple Intelligence models via the Foundation Models framework.

## Requirements
- Swift 6.2 or newer
- macOS 26 or newer with Apple Intelligence available and enabled (compiler reports the Foundation Models APIs as macOS 26+)

## Build
```bash
swift build
```

## Run the web server (port 2929)
```bash
swift run FoundationAPI
```

### Endpoints
- `GET /health` → returns `ok`
- `POST /generate` with JSON body `{ "prompt": "your text" }` → returns the prompt and the generated response using the on-device model

Example:
```bash
curl -X POST \
	-H "Content-Type: application/json" \
	-d '{"prompt":"Write a haiku about Xcode"}' \
	http://localhost:2929/generate
```

The server checks model availability and reports a clear error if the on-device model is unavailable, not enabled, or still downloading.

## Behavior
- Runs an HTTP server on port 2929 using Hummingbird.
- Creates a `LanguageModelSession` with concise instructions and temperature 0.7, maximum 256 response tokens.
- Returns JSON with both the input prompt and the model response.

## Next steps
- Add guided generation or tool-calling examples.
- Add tests under a new `Tests/` target when functionality grows.
