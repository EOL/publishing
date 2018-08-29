class DataController < ApplicationController
  include DataAssociations
  helper :data
  protect_from_forgery

  def show
    data = TraitBank.by_trait(params[:id])
    build_associations(data)
    @data = data.first
    @resources = TraitBank.resources([@data])
    @page = Page.find(@data[:page_id])
    @show_taxon = params[:show_taxon] && params[:show_taxon] == "true"
    render :layout => false
  end
end
