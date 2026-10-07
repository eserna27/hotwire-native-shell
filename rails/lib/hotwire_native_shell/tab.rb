# frozen_string_literal: true

require "uri"

module HotwireNativeShell
  class Tab
    attr_reader :id, :title, :titles, :path, :icon, :sf_symbol, :android_icon, :url, :active_proc, :auth

    def initialize(id:, title:, path:, auth:, icon: "home", titles: nil, sf_symbol: nil, android_icon: nil, url: nil, active: nil)
      @id = id.to_s
      @title = title.to_s
      @path = path.to_s
      @auth = auth.to_sym
      @icon = (icon.presence || "home").to_s
      @titles = normalize_titles(titles)
      @sf_symbol = sf_symbol&.to_s.presence
      @android_icon = android_icon&.to_s.presence
      @url = url&.to_s.presence
      @active_proc = active
      validate!
    end

    # Cold-start document. No `active` key: the shell selects the first tab.
    def config_json
      {
        "id" => id,
        "title" => title,
        "titles" => titles,
        "path" => path,
        "url" => url,
        "icon" => icon,
        "sf_symbol" => sf_symbol,
        "android_icon" => android_icon
      }.compact
    end

    def bridge_attributes(base_url:, active:)
      {
        id: id,
        title: localized_title,
        path: path,
        icon: icon,
        sf_symbol: sf_symbol,
        android_icon: android_icon,
        url: absolute_url(base_url),
        href: path,
        active: active
      }.compact
    end

    def localized_title(locale = I18n.locale)
      return title if titles.nil? || titles.empty?

      tag = locale.to_s.tr("_", "-").downcase
      language = tag.split("-", 2).first
      titles[tag] || titles[language] || title.presence || titles["en"] || titles["es"] || titles.values.compact.first.to_s
    end

    def matches_request?(request)
      if url
        begin
          host = URI.parse(url).host
        rescue URI::InvalidURIError
          host = nil
        end
        return false if host.present? && !same_host?(host, request.host)
      end

      path_matches?(path, request.path.to_s)
    end

    private

    def validate!
      raise ArgumentError, "tab id #{id.inspect} must match #{Contract::TAB_ID}" unless Contract::TAB_ID.match?(id)
      raise ArgumentError, "tab #{id} needs a title" if title.empty?
      raise ArgumentError, "tab #{id} path must not contain a scheme or whitespace" if path.match?(%r{\A[a-z][a-z0-9+.-]*://}i) || path.match?(/\s/)
      raise ArgumentError, "tab #{id} needs a path" if path.empty?
      return if url.nil?
      raise ArgumentError, "tab #{id} url must be http or https" unless url.match?(%r{\Ahttps?://}i)
    end

    def normalize_titles(titles)
      return nil if titles.nil?

      titles.each_with_object({}) do |(key, value), map|
        next if value.nil?

        map[key.to_s.tr("_", "-").downcase] = value.to_s
      end
    end

    def absolute_url(base_url)
      return url if url
      return nil if base_url.blank?

      "#{base_url.to_s.sub(%r{/+\z}, "")}#{path.start_with?("/") ? path : "/#{path}"}"
    end

    def path_matches?(tab_path, request_path)
      current = request_path.empty? ? "/" : request_path
      return true if tab_path.empty? || tab_path == "/"

      current == tab_path || current.start_with?("#{tab_path}/")
    end

    def same_host?(left, right)
      left.to_s.downcase.delete_suffix(".") == right.to_s.downcase.delete_suffix(".")
    end
  end
end
