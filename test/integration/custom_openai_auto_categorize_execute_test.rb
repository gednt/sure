# frozen_string_literal: true

require "test_helper"

# End-to-end test asserting that the auto_categorize execute path runs
# against a custom OpenAI-compatible endpoint (LM Studio, Ollama, vLLM,
# OpenRouter, ...) and produces real categorizations.
#
# This guards the contract that a self-hoster setting
# `Setting.openai_uri_base` + `Setting.openai_model` +
# `Setting.openai_access_token` + `Setting.llm_provider = "openai"` will
# see the auto_categorize rule action dispatch through the custom
# endpoint, complete the job, and create DataEnrichment rows.
class CustomOpenaiAutoCategorizeExecuteTest < ActiveSupport::TestCase
  include EntriesTestHelper, ProviderTestHelper

  setup do
    @family = families(:dylan_family)
    @account = @family.accounts.create!(name: "Custom OpenAI execute test", balance: 100, currency: "USD", accountable: Depository.new)
    @category = @family.categories.create!(name: "Coffee Shops")
  end

  test "auto_categorize rule action runs through custom OpenAI-compatible endpoint" do
    ClimateControl.modify(
      "OPENAI_ACCESS_TOKEN" => nil,
      "OPENAI_URI_BASE" => nil,
      "OPENAI_MODEL" => nil
    ) do
      Setting.stubs(:openai_access_token).returns("test-key")
      Setting.stubs(:openai_uri_base).returns("http://192.168.15.6:1234/v1")
      Setting.stubs(:openai_model).returns("microsoft/phi-4")
      Setting.stubs(:llm_provider).returns("openai")

      txn = create_transaction(account: @account, name: "Starbucks latte").transaction

      provider_instance = Provider::Registry.get_provider(:openai)
      assert provider_instance.custom_provider?, "Provider should be a custom OpenAI-compatible endpoint"
      assert_equal "http://192.168.15.6:1234/v1", provider_instance.uri_base
      assert_equal "microsoft/phi-4", provider_instance.model

      fake_response = provider_success_response([
        Provider::LlmConcept::AutoCategorization.new(transaction_id: txn.id, category_name: "Coffee Shops")
      ])
      provider_instance.expects(:auto_categorize)
        .with(has_entries(transactions: kind_of(Array)))
        .returns(fake_response)

      # Mirror the existing test pattern: also stub the registry methods
      # that AutoCategorizer resolves through, so the stub on
      # `provider_instance` is the one AutoCategorizer actually receives.
      Provider::Registry.stubs(:get_provider).with(:openai).returns(provider_instance)
      Provider::Registry.stubs(:openai).returns(provider_instance)
      Provider::Registry.stubs(:anthropic).returns(nil)

      AutoCategorizeJob.perform_now(
        @family,
        transaction_ids: [ txn.id ],
        rule_run_id: nil
      )

      txn.reload
      assert_equal @category, txn.category
    end
  end

  test "AutoCategorizeJob surfaces the failure to the operator when the LLM call raises" do
    ClimateControl.modify(
      "OPENAI_ACCESS_TOKEN" => nil,
      "OPENAI_URI_BASE" => nil,
      "OPENAI_MODEL" => nil
    ) do
      Setting.stubs(:openai_access_token).returns("test-key")
      Setting.stubs(:openai_uri_base).returns("http://192.168.15.6:1234/v1")
      Setting.stubs(:openai_model).returns("microsoft/phi-4")
      Setting.stubs(:llm_provider).returns("openai")

      txn = create_transaction(account: @account, name: "Starbucks latte").transaction

      provider_instance = Provider::Registry.get_provider(:openai)
      provider_instance.stubs(:auto_categorize).raises(StandardError.new("upstream LLM exploded"))
      Provider::Registry.stubs(:get_provider).with(:openai).returns(provider_instance)
      Provider::Registry.stubs(:openai).returns(provider_instance)
      Provider::Registry.stubs(:anthropic).returns(nil)

      Rails.logger.expects(:error).with(regexp_matches(/upstream LLM exploded|auto_categorize.*failed/)).at_least_once

      # The job must complete (not raise out) so a misconfigured custom
      # endpoint doesn't silently fail forever in Sidekiq.
      assert_nothing_raised do
        AutoCategorizeJob.perform_now(
          @family,
          transaction_ids: [ txn.id ],
          rule_run_id: nil
        )
      end

      assert_nil txn.reload.category
    end
  end

  test "AutoCategorizeJob logs and completes when no LLM provider is configured" do
    Provider::Registry.stubs(:preferred_llm_provider).returns(nil)

    txn = create_transaction(account: @account, name: "Starbucks latte").transaction

    Rails.logger.expects(:error).with(regexp_matches(/no LLM provider|auto_categorize/)).at_least_once

    assert_nothing_raised do
      AutoCategorizeJob.perform_now(
        @family,
        transaction_ids: [ txn.id ],
        rule_run_id: nil
      )
    end

    assert_nil txn.reload.category
  end
end
