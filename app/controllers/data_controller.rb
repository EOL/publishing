class DataController < ApplicationController
  include DataAssociations
  helper :data
  protect_from_forgery

  def show
    data = TraitBank.by_trait_and_page(params[:id], params[:page_id])
    raise ActiveRecord::RecordNotFound if !data || data.empty?
    @data = data.first
    @page = Page.find(@data[:page_id])
    @hide_pred_when_closed = params[:hide_pred_when_closed].present? ? params[:hide_pred_when_closed] : false

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

