class EditorPagesController < ApplicationController
  def show
    @editor_page = EditorPage.friendly.find(params[:editor_page_id])
    @editor_page_content = @editor_page.published_for_locale(I18n.locale)

    if !@editor_page_content
      @editor_page_content = @editor_page.find_published_for_locale(I18n.locale) 
    end
  end
end
