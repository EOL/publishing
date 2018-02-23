class ResourcesController < ApplicationController
  def index
    @resources = Resource.order('updated_at DESC').page(params[:page] || 1).per_page(10)
  end

  def show
    @resource = Resource.find(params[:id])
  end

  def republish
    raise "Unauthorized" unless is_admin?
    @resource = Resource.find(params[:resource_id])
    ImportRun.delay(queue: 'harvest').now(@resource)
    flash[:notice] = "#{@resource.name} will be published in the background. Watch this page for updates."
    redirect_to @resource
  end

  def import_traits
    raise "Unauthorized" unless is_admin?
    @resource = Resource.find(params[:resource_id])
    @resource.delay(queue: 'harvest').import_traits(1)
    flash[:notice] = "Background job for import of traits started."
    redirect_to @resource
  end
end
