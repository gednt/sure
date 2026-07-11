## Context

The current application uses OpenAI for various features (chat, autotagging/merchant categorization, embeddings). While the chat feature correctly supports custom OpenAI-compatible API base URIs (like `OPENAI_URI_BASE` for local models or proxy endpoints), other features like autotag and embeddings often fallback to hardcoded `api.openai.com` URIs or use incorrectly initialized OpenAI clients. This causes failures when attempting to run the app entirely on self-hosted or OpenAI-compatible models (e.g., vLLM, LM Studio).

## Goals / Non-Goals

**Goals:**
- Ensure all instances of OpenAI client initialization use the configured `OPENAI_URI_BASE` consistently.
- Remove hardcoded instances of `https://api.openai.com`.
- Make features like autotagging, auto-detect merchants, and embeddings work reliably with OpenAI-compatible endpoints.

**Non-Goals:**
- Adding support for entirely different LLM providers (e.g., Anthropic, Gemini) if they don't support the OpenAI API format natively.
- Modifying the system prompts themselves, unless strictly necessary for compatibility.

## Decisions

- **Consistent Configuration**: We will ensure that the OpenAI client follows a strict fallback chain for configuration everywhere it is instantiated (e.g., in `VectorStore::Embeddable` and merchant detection services). It must check `ENV["OPENAI_URI_BASE"]` first, then fallback to `Setting.openai_uri_base` (the user configuration from the settings screen), and finally fallback to the default endpoint.
- **Remove Hardcodes**: Any explicit mention of `api.openai.com` that overrides or ignores the environment variables and user configuration will be patched.

## Risks / Trade-offs

- **Risk**: Custom local models might not support advanced features like function calling or specific JSON modes required by autotagging.
  - **Mitigation**: This is an operational risk left to the user to provide a capable model. The application will pass the requests through; model capability is outside the scope of this connection fix.
