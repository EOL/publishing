class PageIconsController < ApplicationController
  def create
    return redirect_to new_user_session_path unless signed_in?
    authorize :page_icon, :create?
    PageIcon.create(icon_params.merge(user_id: current_user.id))
    medium = Medium.find(icon_params[:medium_id])
    flash[:notice] = I18n.t(:page_icon_created, name: medium.name)
    redirect_to page_url(icon_params[:page_id])
  end

private

  def icon_params
    params.permit([:page_id, :medium_id])
  end
end
