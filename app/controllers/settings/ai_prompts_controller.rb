class Settings::AiPromptsController < ApplicationController
  layout "settings"

  def show
    @breadcrumbs = [
      [ t("breadcrumbs.home"), root_path ],
      [ t("breadcrumbs.ai_prompts"), nil ]
    ]
    @family = Current.family
    @assistant_config = Assistant.config_for(OpenStruct.new(user: Current.user))
    @effective_model = Provider::Registry.preferred_llm_provider&.model || Provider::Openai::DEFAULT_MODEL
  end
end
