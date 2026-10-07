# frozen_string_literal: true

class PagesController < ApplicationController
  def chrome
    @title = "Hello | itsjustmy.blog"
    @share_url = "https://itsjustmy.blog/posts/1"
    @share_title = "Hello"
    @menu = params[:menu].presence || "overflow"
    render :chrome
  end
end
