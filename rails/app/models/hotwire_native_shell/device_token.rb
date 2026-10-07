# frozen_string_literal: true

module HotwireNativeShell
  class DeviceToken < ActiveRecord::Base
    self.table_name = "hotwire_native_shell_device_tokens"

    belongs_to :owner, polymorphic: true, optional: true

    validates :token, presence: true, uniqueness: true, length: { maximum: 4096 }
    validates :provider, presence: true, length: { maximum: 32 }
    validates :platform, inclusion: { in: %w[ios android] }, allow_nil: true

    def self.placeholder?(token, provider)
      token.to_s == Contract::PLACEHOLDER_TOKEN || provider.to_s == Contract::PLACEHOLDER_PROVIDER
    end

    def self.register!(token:, provider:, platform: nil, owner: nil)
      record = find_or_initialize_by(token: token.to_s)
      record.provider = provider.to_s
      normalized = platform.to_s.downcase.presence
      record.platform = %w[ios android].include?(normalized) ? normalized : nil
      record.owner = owner if owner
      record.last_seen_at = Time.current
      record.save!
      record
    end
  end
end
