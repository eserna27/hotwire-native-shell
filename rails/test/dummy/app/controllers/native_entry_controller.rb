# frozen_string_literal: true

class NativeEntryController < ApplicationController
  include HotwireNativeShell::NativeEntry

  def root
    render plain: "root"
  end

  def show
    render plain: "entry"
  end
end
