class AutoCategorizeAllJob < ApplicationJob
  queue_as :scheduled
  sidekiq_options lock: :until_executed, on_conflict: :log

  def perform
    Rails.logger.info("Starting scheduled auto-categorize for all families")
    Family.find_each do |family|
      ids = family.uncategorized_enrichable_transaction_ids
      next if ids.empty?

      family.auto_categorize_transactions_later(family.transactions.where(id: ids))
    rescue => e
      Rails.logger.error("Failed to auto-categorize family #{family.id}: #{e.message}")
    end
    Rails.logger.info("Completed scheduled auto-categorize for all families")
  end
end
