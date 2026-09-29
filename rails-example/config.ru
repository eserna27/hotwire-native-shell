# frozen_string_literal: true

require "json"
require "rack"
require_relative "lib/native_config"

# Sketch server for GET /native/config. Not the itsjustmy.blog app.
class NativeConfigApp
  def call(env)
    request = Rack::Request.new(env)
    case [request.request_method, request.path_info]
    when ["GET", "/native/config"]
      json(NativeConfig.payload)
    when ["GET", "/configurations/android_v1.json"], ["GET", "/configurations/ios_v1.json"]
      json(NativeConfig.path_configuration)
    when ["GET", "/"], ["GET", "/index.html"]
      html
    else
      [404, { "content-type" => "text/plain; charset=utf-8" }, ["not found\n"]]
    end
  end

  private

  def json(payload)
    body = JSON.generate(payload)
    [200, { "content-type" => "application/json; charset=utf-8" }, [body]]
  end

  def html
    body = File.read(File.expand_path("public/index.html", __dir__))
    [200, { "content-type" => "text/html; charset=utf-8" }, [body]]
  end
end

run NativeConfigApp.new
