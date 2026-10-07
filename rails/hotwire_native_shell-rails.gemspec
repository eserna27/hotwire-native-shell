# frozen_string_literal: true

require_relative "lib/hotwire_native_shell/version"

Gem::Specification.new do |spec|
  spec.name = "hotwire_native_shell-rails"
  spec.version = HotwireNativeShell::VERSION
  spec.authors = [ "eserna27" ]
  spec.email = [ "eserna27@users.noreply.github.com" ]
  spec.summary = "Rails side of the Hotwire Native shell contract"
  spec.description = "Routes, config, bridge helpers, and push delivery for a Hotwire Native shell. MIT."
  spec.homepage = "https://github.com/eserna27/hotwire-native-shell"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/eserna27/hotwire-native-shell"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,lib}/**/*", "MIT-LICENSE", "README.md"]
  end
  spec.require_paths = [ "lib" ]

  spec.add_dependency "rails", ">= 7.2", "< 8.2"
  spec.add_dependency "net-http2", ">= 0.18", "< 1"
end
