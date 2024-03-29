# frozen_string_literal: true

module Jobs
  class CallDiscourseHub < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      if SiteSetting.version_checks? &&
           (DiscourseUpdates.updated_at.nil? || DiscourseUpdates.updated_at < (1.minute.ago))
        begin
          prev_missing_versions_count = DiscourseUpdates.missing_versions_count || 0

          json = DiscourseHub.discourse_version_check
          DiscourseUpdates.last_installed_version = Discourse::VERSION::STRING
          DiscourseUpdates.latest_version = json["latestVersion"]
          DiscourseUpdates.critical_updates_available = json["criticalUpdates"]
          DiscourseUpdates.missing_versions_count = json["missingVersionsCount"]
          DiscourseUpdates.updated_at = Time.zone.now
          DiscourseUpdates.missing_versions = json["versions"]

          if SiteSetting.new_version_emails && json["missingVersionsCount"] > (0) &&
               prev_missing_versions_count < (json["missingVersionsCount"].to_i)
            message = VersionMailer.send_notice
            Email::Sender.new(message, :new_version).send
          end
        rescue => e
          raise e unless Rails.env.development? # Fail version check silently in development mode
        end
      end

      DiscourseHub.discover_enrollment if SiteSetting.include_in_discourse_discover?
      true
    end
  end
end
