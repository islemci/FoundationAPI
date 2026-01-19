# FoundationAPI

A Swift HTTP server that provides a REST interface to Apple's on-device Foundation Models (Apple Intelligence). Uses Hummingbird as the web framework.

## Requirements
- Swift 6.2 or newer
- macOS 26 or newer with Apple Intelligence available and enabled (compiler reports the Foundation Models APIs as macOS 26+)

## Build
```bash
swift build
```

## Run the web server (port 2929)

**Production mode:**
```bash
swift run FoundationAPI
```

**Debug mode:**
```bash
swift run FoundationAPI --debug
```

## API Endpoints

### Health Check
```bash
GET /health
```
Returns `ok` if the server is running and the model is available.

### Generate Text
```bash
POST /generate
Content-Type: application/json

{ "prompt": "your text" }
```

Returns JSON with both the input prompt and the model-generated response.

**Example:**
```bash
curl -X POST \
	-H "Content-Type: application/json" \
	-d '{"prompt":"Write a haiku about Xcode"}' \
	http://localhost:2929/generate
```

### OpenAI-Compatible Completions
```bash
POST /v1/completions
Content-Type: application/json

{
  "prompt": "your text",
  "model": "auto",
  "max_tokens": 256,
  "temperature": 0.7,
  "stream": false
}
```

Returns OpenAI-compatible completion response format.

**Example:**
```bash
curl -X POST \
	-H "Content-Type: application/json" \
	-d '{
		"prompt": "Write a haiku about Xcode",
		"model": "auto",
		"max_tokens": 256,
		"temperature": 0.7
	}' \
	http://localhost:2929/v1/completions
```

## Logging

The application supports runtime-configurable log levels:

- **Normal mode** (default): Only errors are displayed
- **Debug mode**: Includes detailed debug information about requests and model operations

Enable debug mode with the `--debug` flag when running:
```bash
swift run FoundationAPI --debug
```

Debug logging is controlled at runtime, so you don't need to rebuild to toggle debug output.

## Behavior
- Runs an HTTP server on port 2929 using Hummingbird.
- Creates a `LanguageModelSession` with concise instructions and temperature 0.7, maximum 256 response tokens.
- Returns JSON with the input prompt and the model response.
- Checks model availability and reports clear errors if the on-device model is unavailable, not enabled, or still downloading.