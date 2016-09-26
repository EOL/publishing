class MediaController < ApplicationController
  layout "application"

  def show
    @medium = Medium.find(params[:id])
  end
end
