class PagesController < ApplicationController
  def show
    @page = Page.where(id: params[:id]).preloaded.first
    raise "404" unless @page
    @resources = TraitBank.resources(@page.traits)
  end
end
