# frozen_string_literal: true

module HotwireNativeShell
  class Engine < ::Rails::Engine
    isolate_namespace HotwireNativeShell

    initializer "hotwire_native_shell.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include HotwireNativeShell::ControllerMethods
        helper HotwireNativeShell::NativeHelper
      end
    end

    initializer "hotwire_native_shell.filter_parameters" do |app|
      app.config.filter_parameters += %i[token private_key service_account_json]
    end
  end
end
