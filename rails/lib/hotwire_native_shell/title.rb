# frozen_string_literal: true

module HotwireNativeShell
  module Title
    module_function

    # Drops a trailing " | suffix" so the native bar shows the page name.
    # A title that is only the suffix comes back as the suffix.
    def without_suffix(title, suffix)
      text = title.to_s.strip
      return text if suffix.nil? || suffix.to_s.empty?

      stripped = text.sub(/\s*\|\s*#{Regexp.escape(suffix.to_s)}\s*\z/, "").strip
      stripped.empty? ? suffix.to_s : stripped
    end
  end
end
