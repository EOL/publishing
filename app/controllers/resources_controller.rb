class ResourcesController < ApplicationController
  def show
    @resource = Resource.find(params[:id])
  end
end
