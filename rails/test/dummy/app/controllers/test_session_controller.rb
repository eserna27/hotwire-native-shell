# frozen_string_literal: true

class TestSessionController < ApplicationController
  def create
    session[:user_id] = params[:user_id]
    head :no_content
  end
end
