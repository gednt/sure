## Why

We need full OpenAI-compatible API support across the entire codebase. Currently, only the chat feature supports custom OpenAI-compatible endpoints properly. Other features, like autotagging (or merchant/category auto-detection), do not work with these custom endpoints despite previous fixes, likely due to inconsistent client initialization or lingering hardcoded base URIs.

## What Changes

- Standardize OpenAI client initialization across all features (chat, autotag, embeddings, merchant detection).
- Ensure that base URIs (`OPENAI_URI_BASE` or similar) are consistently respected everywhere. The fallback chain must be: Environment Variable (`ENV["OPENAI_URI_BASE"]`) -> User Configuration (`Setting.openai_uri_base` from the settings screen) -> Default API.
- Remove any lingering hardcoded `https://api.openai.com` URIs that might bypass custom API endpoints.

## Capabilities

### New Capabilities
- `openai-compatible-support`: Ensures all AI integrations can use custom OpenAI-compatible endpoints (e.g., vLLM, Ollama, LM Studio) seamlessly.

### Modified Capabilities

## Impact

- AI client initializers and configuration modules.
- Autotagging, auto-categorization, and merchant detection features.
- Vector store embeddings and other background jobs utilizing the OpenAI client.
