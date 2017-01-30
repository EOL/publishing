class MediaController < ApplicationController
  layout "application"

  def show
    @medium = Medium.where(id: params[:id]).includes(:license,
      :bibliographic_citation, :location, attributions: :role).first
  end
end
