class MediaController < ApplicationController
  layout "application"

  before_action :get_medium
  before_action :require_admin, except: :show

  def show
  end

  def fix_source_pages
    @medium.fix_source_pages
    get_medium # You need to reload it for it to display properly.
    flash[:notice] = '"Appears on" pages have been repaired. The list now reflects what is in the database.'
    render action: :show
  end

  def hide
    raise ActionController::BadRequest.new("medium already hidden") if @medium.hidden?
    @medium.build_hidden_medium
    @medium.hidden_medium.resource_pk = @medium.resource_pk
    @medium.hidden_medium.resource_id = @medium.resource_id
    @medium.save!

    hide_unhide_redirect("hidden")
  end

  def unhide
    raise ActionController::BadRequest.new("medium not hidden") if !@medium.hidden?
    @medium.hidden_medium.destroy!
    hide_unhide_redirect("un-hidden")
  end
    

private
  def hide_unhide_redirect(msg)
    redirect_to (params[:page_id].present? ? page_media_path(params[:page_id]) : @medium), notice: "Medium #{@medium.id} #{msg}"
  end

  def get_medium
    @medium = Medium.includes(
      :license,
      :bibliographic_citation,
      :location,
      page_contents: {
        page: [
          {
            native_node: [
              :scientific_names,
              {
                node_ancestors: {
                  ancestor: :page
                }
              }
            ]
          },
          :preferred_vernaculars
        ]
      },
      attributions: :role
    ).find(params[:id] || params[:medium_id])
  end
end
