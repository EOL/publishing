class ResourcesController < ApplicationController
  def index
    @resources = Resource.order('updated_at DESC').page(params[:page] || 1).per_page(10)
  end

  def show
    # @resource = Resource.find(params[:id])
    result = ResourceApi.get_resource_using_id(params[:id])
    @resource = Resource.new(name: result["name"],origin_url: result["original_url"],uploaded_url: result["uploaded_url"],
                      type: result["type"],path: result["path"],last_harvested_at: result["last_harvested_at"],harvest_frequency: result["harvest_frequency"],
                      day_of_month: result["day_of_month"],nodes_count: result["nodes_count"],position: result["position"],is_paused: result["_paused"],
                      is_approved: result["_approved"],is_trusted: result["_trusted"],is_autopublished: result["_autopublished"],is_forced: result["_forced"],
                      dataset_license: result["dataset_license"],dataset_rights_statement: result["dataset_rights_statement"],
                      dataset_rights_holder: result["dataset_rights_holder"],default_license_string: result["default_license_string"],
                      default_rights_statement: result["default_rights_statement"],default_rights_holder: result["default_rights_holder"],
                      default_language_id: result["default_language_id"])
  end

  def sync
    raise "Unauthorized" unless is_admin?
    if (info = ImportLog.already_running?)
      flash[:alert] = info
    else
      Publishing.delay(queue: 'harvest').sync
      flash[:notice] = "Resources will be checked against the repository."
    end
    redirect_to resources_path
  end

  def clear_publishing
    raise "Unauthorized" unless is_admin?
    ImportLog.all_clear!
    flash[:notice] = "All clear. You can sync, now."
    redirect_to resources_path
  end

  def republish
    raise "Unauthorized" unless is_admin?
    @resource = Resource.find(params[:resource_id])
    Delayed::Job.enqueue(RepublishJob.new(@resource.id))
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
