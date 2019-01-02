class DataController < ApplicationController
  include DataAssociations
  helper :data
  protect_from_forgery

  def show
    data = TraitBank.by_trait(params[:id])
    raise ActiveRecord::RecordNotFound if !data || data.empty?
    @data = data.first
    @page = Page.find(@data[:page_id])

    if request.xhr?
      build_associations(data)
      @resources = TraitBank.resources([@data])
      @show_taxon = params[:show_taxon] && params[:show_taxon] == "true"
      render :layout => false
    else
      redirect_to "#{page_data_path(page_id: @page.id, predicate: @data[:predicate][:uri])}#trait_id=#{@data[:id]}"
    end
  end
end

