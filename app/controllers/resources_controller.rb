class ResourcesController < ApplicationController
  def index
    @resources = Resource.order(:name).page(params[:page] || 1).per_page(30)
  end

  def show
    @resource = Resource.find(params[:id])
  end
end
