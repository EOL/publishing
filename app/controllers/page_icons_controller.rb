class PageIconsController < ApplicationController
  def create
    # TODO: permissions
    PageIcon.create(icon_params.merge(user_id: current_user.id))
    redirect_to page_url(icon_params[:page_id])
  end

private

  def icon_params
    params.permit([:page_id, :medium_id])
  end
end
