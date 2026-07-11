## ADDED Requirements

### Requirement: Global OpenAI Compatible Endpoint Support
The system SHALL use the configured OpenAI base URI for all AI-driven features, falling back through the hierarchy: Environment Variable -> User Settings Configuration -> Default OpenAI endpoint.

#### Scenario: Using a custom OpenAI URI configured via environment variables
- **WHEN** the system processes an autotagging or categorization job
- **AND** a custom OpenAI compatible endpoint is configured via environment variables
- **THEN** the system routes the request to the custom endpoint instead of `api.openai.com`

#### Scenario: Using a custom OpenAI URI configured via user settings
- **WHEN** the system generates embeddings for vector storage
- **AND** the environment variable is NOT set
- **AND** a custom OpenAI compatible endpoint is configured in the user settings (`Setting.openai_uri_base`)
- **THEN** the system routes the embedding request to the custom endpoint configured in settings
