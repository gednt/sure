require "test_helper"

class Settings::AiPromptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "show renders successfully" do
    get settings_ai_prompts_url
    assert_response :success
  end

  test "effective model defaults to openai default model" do
    Provider::Registry.stubs(:preferred_llm_provider).returns(nil)
    get settings_ai_prompts_url
    assert_response :success
    assert_includes response.body, "[#{Provider::Openai::DEFAULT_MODEL}]"
  end

  test "effective model uses configured custom openai model" do
    Setting.openai_uri_base = "http://localhost:11434/v1"
    Setting.openai_model = "llama3.1"
    Setting.llm_provider = "openai"

    openai_provider = Provider::Openai.new("fake-token", uri_base: "http://localhost:11434/v1", model: "llama3.1")
    Provider::Registry.stubs(:preferred_llm_provider).returns(openai_provider)

    get settings_ai_prompts_url
    assert_response :success
    assert_includes response.body, "[llama3.1]"

    Setting.openai_uri_base = nil
    Setting.openai_model = nil
  end

  test "effective model uses configured anthropic model" do
    Setting.llm_provider = "anthropic"
    Setting.anthropic_model = "claude-sonnet-4-5"

    anthropic_provider = Provider::Anthropic.new("fake-token", model: "claude-sonnet-4-5")
    Provider::Registry.stubs(:preferred_llm_provider).returns(anthropic_provider)

    get settings_ai_prompts_url
    assert_response :success
    assert_includes response.body, "[claude-sonnet-4-5]"

    Setting.llm_provider = "openai"
    Setting.anthropic_model = nil
  end
end
