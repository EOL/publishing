class PagesController < ApplicationController
  def show
    @page = Page.where(id: params[:id]).preloaded.first
  end
end
