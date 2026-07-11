require "test_helper"

class Family::AutoCategorizerTest < ActiveSupport::TestCase
  include EntriesTestHelper, ProviderTestHelper

  setup do
    @family = families(:dylan_family)
    @account = @family.accounts.create!(name: "Rule test", balance: 100, currency: "USD", accountable: Depository.new)
    @llm_provider = mock
    Provider::Registry.stubs(:get_provider).with(:openai).returns(@llm_provider)
  end

  test "auto-categorizes transactions" do
    txn1 = create_transaction(account: @account, name: "McDonalds").transaction
    txn2 = create_transaction(account: @account, name: "Amazon purchase").transaction
    txn3 = create_transaction(account: @account, name: "Netflix subscription").transaction

    test_category = @family.categories.create!(name: "Test category")

    provider_response = provider_success_response([
      AutoCategorization.new(transaction_id: txn1.id, category_name: test_category.name),
      AutoCategorization.new(transaction_id: txn2.id, category_name: test_category.name),
      AutoCategorization.new(transaction_id: txn3.id, category_name: nil)
    ])

    @llm_provider.expects(:auto_categorize).returns(provider_response).once

    assert_difference "DataEnrichment.count", 2 do
      Family::AutoCategorizer.new(@family, transaction_ids: [ txn1.id, txn2.id, txn3.id ]).auto_categorize
    end

    assert_equal test_category, txn1.reload.category
    assert_equal test_category, txn2.reload.category
    assert_nil txn3.reload.category

    # After auto-categorization, only successfully categorized transactions are locked
    # txn3 remains enrichable since it didn't get a category (allows retry)
    assert_equal 1, @account.transactions.reload.enrichable(:category_id).count
  end

  test "resolves provider through Provider::Registry.preferred_llm_provider" do
    Provider::Registry.unstub(:get_provider)
    openai_provider = mock
    anthropic_provider = mock
    Provider::Registry.stubs(:openai).returns(openai_provider)
    Provider::Registry.stubs(:anthropic).returns(anthropic_provider)
    Setting.stubs(:llm_provider).returns("openai")

    auto_categorizer = Family::AutoCategorizer.new(@family, transaction_ids: [])

    assert_same openai_provider, auto_categorizer.send(:llm_provider)
  end

  test "uses anthropic provider when Setting.llm_provider is anthropic and never resolves Openai" do
    Provider::Registry.unstub(:get_provider)
    openai_provider = mock
    anthropic_provider = mock
    Provider::Registry.stubs(:openai).returns(openai_provider)
    Provider::Registry.stubs(:anthropic).returns(anthropic_provider)
    Setting.stubs(:llm_provider).returns("anthropic")
    Provider::Openai.expects(:effective_model).never

    auto_categorizer = Family::AutoCategorizer.new(@family, transaction_ids: [])

    assert_same anthropic_provider, auto_categorizer.send(:llm_provider)
  end

  test "constructs Provider::Openai with configured uri_base for custom endpoints" do
    ClimateControl.modify(
      "OPENAI_ACCESS_TOKEN" => nil,
      "OPENAI_URI_BASE" => nil,
      "OPENAI_MODEL" => nil
    ) do
      Setting.stubs(:openai_access_token).returns("test-key")
      Setting.stubs(:openai_uri_base).returns("http://192.168.15.6:1234/v1")
      Setting.stubs(:openai_model).returns("microsoft/phi-4")
      Setting.stubs(:llm_provider).returns("openai")
      Provider::Registry.unstub(:get_provider)

      auto_categorizer = Family::AutoCategorizer.new(@family, transaction_ids: [])
      provider = auto_categorizer.send(:llm_provider)

      assert_instance_of Provider::Openai, provider
      assert_equal "http://192.168.15.6:1234/v1", provider.uri_base
      assert provider.custom_provider?
    end
  end

  private
    AutoCategorization = Provider::LlmConcept::AutoCategorization
end
