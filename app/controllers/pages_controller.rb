class PagesController < ApplicationController

  helper :traits

  def show
    @page = Page.where(id: params[:id]).preloaded.first
    raise "404" unless @page
    @page_title = @page.name
    @media = @page.media.includes(:license).page(params[:page])
    @resources = TraitBank.resources(@page.traits)

    @associations =
      begin
        ids = @page.traits.map { |t| t[:object_page_id] }.compact.sort.uniq
        # TODO: include more when we need it
        Page.where(id: ids).includes(:medium, :native_node, :preferred_vernaculars)
      end
  end
end
