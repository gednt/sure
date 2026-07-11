require "test_helper"

class Rule::ActionExecutor::AutoCategorizeTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  def build_rule
    rule = @family.rules.build(
      name: "Test auto-categorize",
      resource_type: "transaction",
      active: true
    )
    rule.actions.build(action_type: "auto_categorize")
    rule
  end

  test "label returns the openai cost label when openai is the preferred provider" do
    with_self_hosting do
      openai_provider = mock
      openai_provider.stubs(:class).returns(Provider::Openai)
      Provider::Registry.stubs(:preferred_llm_provider).returns(openai_provider)
      Provider::Openai.stubs(:effective_model).returns("gpt-4.1")
      LlmUsage.stubs(:estimate_auto_categorize_cost).returns(0.0123)

      rule = build_rule
      label = Rule::ActionExecutor::AutoCategorize.new(rule).label

      assert_includes label, "Auto-categorize transactions with AI"
      assert_includes label, "per 20 transactions"
    end
  end

  test "label does not call Provider::Openai.effective_model when anthropic is preferred" do
    with_self_hosting do
      anthropic_provider = mock
      anthropic_provider.stubs(:class).returns(Provider::Anthropic)
      Provider::Anthropic.stubs(:effective_model).returns("claude-sonnet-4-6")
      Provider::Registry.stubs(:preferred_llm_provider).returns(anthropic_provider)
      LlmUsage.stubs(:estimate_auto_categorize_cost).returns(0.0456)
      Provider::Openai.expects(:effective_model).never

      rule = build_rule
      label = Rule::ActionExecutor::AutoCategorize.new(rule).label

      assert_includes label, "Auto-categorize transactions with AI"
      assert_includes label, "per 20 transactions"
    end
  end

  test "label surfaces the no-provider message when no LLM provider is configured" do
    with_self_hosting do
      Provider::Registry.stubs(:preferred_llm_provider).returns(nil)

      rule = build_rule
      label = Rule::ActionExecutor::AutoCategorize.new(rule).label

      assert_equal "Auto-categorize transactions with AI (no LLM provider configured)", label
    end
  end

  test "label resolves provider through preferred_llm_provider rather than get_provider(:openai)" do
    with_self_hosting do
      openai_provider = mock
      openai_provider.stubs(:class).returns(Provider::Openai)
      Provider::Registry.expects(:preferred_llm_provider).returns(openai_provider).at_least_once
      Provider::Registry.expects(:get_provider).with(:openai).never
      Provider::Openai.stubs(:effective_model).returns("gpt-4.1")
      LlmUsage.stubs(:estimate_auto_categorize_cost).returns(0.01)

      rule = build_rule
      Rule::ActionExecutor::AutoCategorize.new(rule).label
    end
  end
end
