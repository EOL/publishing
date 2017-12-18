class ResourcesController < ApplicationController
  def index
    @resources = Resource.order('updated_at DESC').page(params[:page] || 1).per_page(10)
  end

  def show
    @resource = Resource.find(params[:id])
  end
end
