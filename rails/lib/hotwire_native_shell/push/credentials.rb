# frozen_string_literal: true

require "json"

module HotwireNativeShell
  module Push
    # Reads APNs and FCM secrets from ENV, then Rails credentials.
    # Nothing in this object is written to disk.
    class Credentials
      def apns
        {
          key_id: fetch("HOTWIRE_NATIVE_SHELL_APNS_KEY_ID", :apns, :key_id),
          team_id: fetch("HOTWIRE_NATIVE_SHELL_APNS_TEAM_ID", :apns, :team_id),
          bundle_id: fetch("HOTWIRE_NATIVE_SHELL_APNS_BUNDLE_ID", :apns, :bundle_id),
          private_key: apns_private_key,
          sandbox: sandbox?
        }
      end

      def fcm_service_account
        raw = ENV["HOTWIRE_NATIVE_SHELL_FCM_SERVICE_ACCOUNT_JSON"].presence
        raw ||= read_path(ENV["HOTWIRE_NATIVE_SHELL_FCM_SERVICE_ACCOUNT_PATH"])
        raw ||= credential(:fcm, :service_account_json)
        account = parse_account(raw)
        project = ENV["HOTWIRE_NATIVE_SHELL_FCM_PROJECT_ID"].presence
        project ||= credential(:fcm, :project_id)
        project ||= account && account["project_id"]
        account["project_id"] = project if account && project
        account
      end

      def require_apns!
        values = apns
        missing = []
        missing << "HOTWIRE_NATIVE_SHELL_APNS_KEY_ID or credentials hotwire_native_shell.apns.key_id" if values[:key_id].blank?
        missing << "HOTWIRE_NATIVE_SHELL_APNS_TEAM_ID or credentials hotwire_native_shell.apns.team_id" if values[:team_id].blank?
        missing << "HOTWIRE_NATIVE_SHELL_APNS_BUNDLE_ID or credentials hotwire_native_shell.apns.bundle_id" if values[:bundle_id].blank?
        missing << "HOTWIRE_NATIVE_SHELL_APNS_KEY or HOTWIRE_NATIVE_SHELL_APNS_KEY_PATH or credentials hotwire_native_shell.apns.private_key" if values[:private_key].blank?
        raise ConfigurationError, "Missing APNs settings: #{missing.join("; ")}" if missing.any?

        values
      end

      def require_fcm!
        account = fcm_service_account
        if account.blank? || account["private_key"].blank? || account["client_email"].blank? || account["project_id"].blank?
          raise ConfigurationError, "Missing FCM service account. Set HOTWIRE_NATIVE_SHELL_FCM_SERVICE_ACCOUNT_JSON or credentials hotwire_native_shell.fcm.service_account_json, plus project_id."
        end

        account
      end

      private

      def apns_private_key
        ENV["HOTWIRE_NATIVE_SHELL_APNS_KEY"].presence ||
          read_path(ENV["HOTWIRE_NATIVE_SHELL_APNS_KEY_PATH"]) ||
          credential(:apns, :private_key)
      end

      def sandbox?
        flag = ENV.fetch("HOTWIRE_NATIVE_SHELL_APNS_SANDBOX") { credential(:apns, :sandbox) }
        ActiveModel::Type::Boolean.new.cast(flag)
      end

      def fetch(env_key, *credential_path)
        ENV[env_key].presence || credential(*credential_path)
      end

      def credential(*path)
        return if !defined?(Rails) || Rails.application.nil?

        Rails.application.credentials.dig(:hotwire_native_shell, *path)
      rescue StandardError
        nil
      end

      def read_path(path)
        return if path.blank?
        return unless File.file?(path)

        File.read(path)
      end

      def parse_account(raw)
        case raw
        when nil, "" then nil
        when Hash then raw.stringify_keys
        else JSON.parse(raw.to_s)
        end
      end
    end
  end
end
