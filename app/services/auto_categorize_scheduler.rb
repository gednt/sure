class AutoCategorizeScheduler
  JOB_NAME = "auto_categorize_all"

  def self.sync!
    Rails.logger.info("[AutoCategorizeScheduler] auto_categorize_enabled=#{Setting.auto_categorize_enabled}, frequency=#{Setting.auto_categorize_frequency}, time=#{Setting.auto_categorize_time}")
    if Setting.auto_categorize_enabled?
      upsert_job
    else
      remove_job
    end
  end

  def self.upsert_job
    time_str = Setting.auto_categorize_time || "03:33"
    timezone_str = Setting.auto_categorize_timezone || "UTC"
    frequency = Setting.auto_categorize_frequency || "daily"

    unless Setting.valid_auto_categorize_time?(time_str)
      Rails.logger.error("[AutoCategorizeScheduler] Invalid time format: #{time_str}, using default 03:33")
      time_str = "03:33"
    end

    unless Setting::AUTO_CATEGORIZE_FREQUENCIES.include?(frequency)
      Rails.logger.error("[AutoCategorizeScheduler] Invalid frequency: #{frequency}, using default daily")
      frequency = "daily"
    end

    hour, minute = time_str.split(":").map(&:to_i)
    timezone = ActiveSupport::TimeZone[timezone_str] || ActiveSupport::TimeZone["UTC"]
    local_time = timezone.now.change(hour: hour, min: minute, sec: 0)
    utc_time = local_time.utc

    cron = case frequency
    when "hourly"
      "#{utc_time.min} * * * *"
    when "every_6_hours"
      "#{utc_time.min} */6 * * *"
    when "every_12_hours"
      "#{utc_time.min} */12 * * *"
    else # daily
      "#{utc_time.min} #{utc_time.hour} * * *"
    end

    job = Sidekiq::Cron::Job.create(
      name: JOB_NAME,
      cron: cron,
      class: "AutoCategorizeAllJob",
      queue: "scheduled",
      description: "Auto-categorize transactions for all families"
    )

    if job.nil? || (job.respond_to?(:valid?) && !job.valid?)
      error_msg = job.respond_to?(:errors) ? job.errors.to_a.join(", ") : "unknown error"
      Rails.logger.error("[AutoCategorizeScheduler] Failed to create cron job: #{error_msg}")
      raise StandardError, "Failed to create auto-categorize schedule: #{error_msg}"
    end

    Rails.logger.info("[AutoCategorizeScheduler] Created cron job with schedule: #{cron} (#{frequency} #{time_str} #{timezone_str})")
    job
  end

  def self.remove_job
    if (job = Sidekiq::Cron::Job.find(JOB_NAME))
      job.destroy
    end
  end
end
