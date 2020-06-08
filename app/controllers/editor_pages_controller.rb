class EditorPagesController < ApplicationController
  def show
    @editor_page = if params[:directory_id]
                     dir = EditorPageDirectory.friendly.find(params[:directory_id])
                     dir.editor_pages.friendly.find(params[:id])
                   else
                     EditorPage.friendly.find(params[:id])
                   end

    @editor_page_content = @editor_page.published_for_locale(I18n.locale)
    if !@editor_page_content
      @editor_page_content = @editor_page.find_published_for_locale(I18n.default_locale) 
    end
  end
end
