class PagesController < ApplicationController
  def show
    @page = Page.where(id: params[:id]).preloaded.first
    @resources = TraitBank.resources(@page.traits)
  end
end
