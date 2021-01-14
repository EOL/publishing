class DataController < ApplicationController
  include DataAssociations
  helper :data
  protect_from_forgery

  def show
    trait_node = TraitNode
      .query_as(:trait)
      .match('(page:Page)-[:trait|:inferred_trait]->(trait)')
      .where('trait.eol_pk': params[:id], 'page.page_id': params[:page_id].to_i)
      .return(:trait)
      .limit(1)
      .first&.[](:trait)

    raise ActiveRecord::RecordNotFound unless trait_node

    @trait = Trait.wrap_node(trait_node)
    @page = Page.find(params[:page_id])
    @hide_pred_when_closed = params[:hide_pred_when_closed].present? ? params[:hide_pred_when_closed] : false

    if request.xhr?
      @show_taxon = params[:show_taxon] && params[:show_taxon] == "true"
      render :layout => false
    else
      redirect_to "#{page_data_path(page_id: @page.id, predicate: @data[:group_predicate][:uri])}#trait_id=#{@data[:id]}"
    end
  end
end
