# Local/privacy notes

The model endpoints in this package point only to `http://127.0.0.1:11434` (Ollama). No remote LLM provider is configured.

Continue itself may still have anonymous product telemetry enabled in the IDE. Continue's official offline guide recommends disabling **Allow Anonymous Telemetry** in the IDE settings when you want an air-gapped/offline setup.

The package does not configure MCP servers, remote documentation crawlers, or remote model APIs. Add those only deliberately.
