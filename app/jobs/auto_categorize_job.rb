class AutoCategorizeJob < ApplicationJob
  queue_as :medium_priority

  def perform(family, transaction_ids: [], rule_run_id: nil)
    modified_count = family.auto_categorize_transactions(transaction_ids)

    # If this job was part of a rule run, report back the modified count
    if rule_run_id.present?
      rule_run = RuleRun.find_by(id: rule_run_id)
      rule_run&.complete_job!(modified_count: modified_count)
    end
  rescue => e
    # The execute path of auto_categorize can raise for several reasons that
    # the operator must see:
    #   - No LLM provider is configured (Family::AutoCategorizer raises
    #     Error, "No LLM provider for auto-categorization").
    #   - The OpenAI-compatible endpoint rejects the request (e.g. wrong
    #     uri_base, wrong model, missing schema support) and the SDK
    #     raises a Faraday/HTTP error.
    #   - The LLM returned a response that the parser cannot turn into
    #     categorizations.
    # Without this rescue the exception propagates out of `perform`, the
    # job ends up in the Sidekiq dead set, and the operator has no idea
    # why auto_categorize "isn't running" on their custom endpoint. We
    # log at error level with family + rule_run + provider context, then
    # let the job complete so we don't poison the queue.
    provider = Provider::Registry.preferred_llm_provider
    Rails.logger.error(
      "[AutoCategorizeJob] auto_categorize failed for family_id=#{family&.id} " \
      "rule_run_id=#{rule_run_id.inspect} " \
      "provider=#{provider&.class&.name} " \
      "uri_base=#{provider.respond_to?(:uri_base) ? provider.uri_base : nil}: " \
      "#{e.class}: #{e.message}"
    )
    0
  end
end
