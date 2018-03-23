class DataController < ApplicationController
  helper :data
  protect_from_forgery

  def show
    @data = TraitBank.by_trait(params[:id]).first
    @resources = TraitBank.resources([@data])
    @page = Page.find(@data[:page_id])
    render :layout => false
  end
end
