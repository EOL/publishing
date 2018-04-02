class ResourcesController < ApplicationController
  def index
    @resources = Resource.order('updated_at DESC').page(params[:page] || 1).per_page(30)
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
end
