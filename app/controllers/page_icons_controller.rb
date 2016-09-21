class PageIconsController < ApplicationController
  def create
    # TODO: permissions
    PageIcon.create(icon_params.merge(user_id: current_user.id))
  end

private

  def icon_params
    params.require(:page_id, :medium_id)
  end
end
