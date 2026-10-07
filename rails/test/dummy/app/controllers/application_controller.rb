# frozen_string_literal: true

class ApplicationController < ActionController::Base
  def user_signed_in?
    session[:user_id].present?
  end
  helper_method :user_signed_in?

  def current_user
    User.find_by(id: session[:user_id]) if session[:user_id]
  end
end
