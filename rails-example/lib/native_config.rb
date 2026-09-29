# frozen_string_literal: true

require "json"

# Reads the shell's canonical JSON. A production Rails app should keep its own
# copy (or build the hash from application config) and not depend on this repo.
module NativeConfig
  module_function

  def shell_root
    File.expand_path("../..", __dir__)
  end

  def payload
    JSON.parse(File.read(File.join(shell_root, "flavors/itsjustmy/assets/native/config.json")))
  end

  def path_configuration
    JSON.parse(File.read(File.join(shell_root, "android/app/src/main/assets/json/path-configuration.json")))
  end
end
