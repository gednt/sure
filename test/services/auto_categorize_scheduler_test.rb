require "test_helper"

class AutoCategorizeSchedulerTest < ActiveSupport::TestCase
  setup do
    Sidekiq::Cron::Job.find("auto_categorize_all")&.destroy
    Setting.auto_categorize_enabled = true
    Setting.auto_categorize_frequency = "daily"
    Setting.auto_categorize_time = "03:33"
    Setting.auto_categorize_timezone = "UTC"
  end

  teardown do
    Sidekiq::Cron::Job.find("auto_categorize_all")&.destroy
    Setting.auto_categorize_enabled = false
    Setting.auto_categorize_frequency = "daily"
    Setting.auto_categorize_time = "03:33"
    Setting.auto_categorize_timezone = "UTC"
  end

  test "enabled + daily creates the cron job with the right cron expression" do
    AutoCategorizeScheduler.sync!

    job = Sidekiq::Cron::Job.find("auto_categorize_all")
    assert_not_nil job
    assert_equal "33 3 * * *", job.cron
    assert_equal "AutoCategorizeAllJob", job.klass
  end

  test "disabled removes the job" do
    Setting.auto_categorize_enabled = false
    AutoCategorizeScheduler.sync!

    job = Sidekiq::Cron::Job.find("auto_categorize_all")
    assert_nil job
  end

  test "every_6_hours uses minute-only cron" do
    Setting.auto_categorize_frequency = "every_6_hours"
    Setting.auto_categorize_time = "03:33"
    AutoCategorizeScheduler.sync!

    job = Sidekiq::Cron::Job.find("auto_categorize_all")
    assert_not_nil job
    assert_equal "33 */6 * * *", job.cron
  end

  test "invalid time logs error and falls back to 03:33" do
    Setting.auto_categorize_time = "invalid-time"
    AutoCategorizeScheduler.sync!

    job = Sidekiq::Cron::Job.find("auto_categorize_all")
    assert_not_nil job
    assert_equal "33 3 * * *", job.cron
  end

  test "default-off creates no job" do
    Setting.auto_categorize_enabled = false
    AutoCategorizeScheduler.sync!

    job = Sidekiq::Cron::Job.find("auto_categorize_all")
    assert_nil job
  end
end
