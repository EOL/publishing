class NodesController < ApplicationController
  def index
    @resource = Resource.find(params[:resource_id])
    @nodes = @resource.nodes.order('scientific_name').includes(:page).by_page(params[:page] || 1).per(15)
  end
end
