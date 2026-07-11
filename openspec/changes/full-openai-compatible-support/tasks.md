## 1. Audit and Discovery

- [ ] 1.1 Identify all instances of OpenAI client initializations (e.g., `OpenAI::Client`, `Langchain::LLM::OpenAI`) across the codebase.
- [ ] 1.2 Identify all hardcoded references to `api.openai.com` across the codebase (e.g., in `VectorStore::Embeddable`).

## 2. Core Implementation

- [ ] 2.1 Update autotagging and auto-categorization services to initialize their OpenAI clients with a fallback chain checking `ENV["OPENAI_URI_BASE"]` first, then `Setting.openai_uri_base`, before relying on default configurations.
- [ ] 2.2 Refactor `app/models/vector_store/embeddable.rb` to correctly utilize custom endpoints without hardcoding `https://api.openai.com/v1/` and follow the same `ENV -> Setting -> Default` fallback.
- [ ] 2.3 Update any other AI-driven services discovered in step 1 to consistently respect custom OpenAI endpoints.

## 3. Testing and Validation

- [ ] 3.1 Verify existing tests pass and update tests if required for any modified client initializers.
- [ ] 3.2 Ensure VCR cassettes or mocks are not failing due to URI updates in the testing environment.
