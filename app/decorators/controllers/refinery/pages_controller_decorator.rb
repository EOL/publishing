Refinery::PagesController.class_eval do
  before_action :set_page_title

  def set_page_title
    @page_title = @page.title
  end
end
