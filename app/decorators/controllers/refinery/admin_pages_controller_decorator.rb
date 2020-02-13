module Refinery::Admin::PagesControllerWithMyParams
  def page_params
     super.merge(params.require(:page).permit(:show_date))
  end
end

Refinery::Admin::PagesController.send(:prepend, Refinery::Admin::PagesControllerWithMyParams)
