require "test_helper"

class AutoCategorizeAllJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "perform enqueues AutoCategorizeJob per family with uncategorized transactions" do
    Family.stubs(:find_each).yields(@family)
    @family.stubs(:uncategorized_enrichable_transaction_ids).returns([ 1, 2 ])

    assert_enqueued_with(job: AutoCategorizeJob) do
      AutoCategorizeAllJob.perform_now
    end
  end

  test "families with no uncategorized transactions are skipped" do
    Family.stubs(:find_each).yields(@family)
    @family.stubs(:uncategorized_enrichable_transaction_ids).returns([])

    assert_no_enqueued_jobs(only: AutoCategorizeJob) do
      AutoCategorizeAllJob.perform_now
    end
  end

  test "a per-family error is logged and does not abort the run" do
    family_error = families(:empty)
    family_success = families(:dylan_family)

    Family.stubs(:find_each).multiple_yields([ family_error ], [ family_success ])

    family_error.stubs(:uncategorized_enrichable_transaction_ids).raises(StandardError, "Database error")
    family_success.stubs(:uncategorized_enrichable_transaction_ids).returns([ 1, 2 ])

    Rails.logger.expects(:error).with(regexp_matches(/Failed to auto-categorize family #{family_error.id}: Database error/)).once

    assert_enqueued_with(job: AutoCategorizeJob) do
      AutoCategorizeAllJob.perform_now
    end
  end
end
