class DataController < ApplicationController
  include DataAssociations
  include TraitBank::Constants

  helper :data
  protect_from_forgery

  def show
    @trait = Trait.find(params[:id])
    page_id = params[:page_id]&.to_i
    trait_rels = page_id.nil? ? ':trait' : TRAIT_RELS

    q = @trait.query_as(:trait)
      .match("(page:Page)-[#{trait_rels}]->(trait)")
      .match("(trait)-[:predicate]->(:Term)-[#{PARENT_TERMS}]->(group_predicate:Term)")
      .where_not('(group_predicate)-[:synonym_of]->(:Term)')

    q = q.where('page.page_id': params[:page_id].to_i) if page_id.present?
      
    query_result = q.return(:page, :group_predicate).limit(1)&.first

    raise ActiveRecord::RecordNotFound if query_result.nil?

    @page = Page.find(query_result[:page].page_id)

    if request.xhr?
      @show_taxon = params[:show_taxon] && params[:show_taxon] == "true"
      render :layout => false
    else
      redirect_to "#{page_data_path(page_id: @page.id, predicate_id: query_result[:group_predicate].id)}#trait_id=#{@trait.id}"
    end
  end
end
