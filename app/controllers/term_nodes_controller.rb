class TermNodesController < ApplicationController
  def show
    term_node = TermNode.find(params[:id])

    url = if term_node.known_type?
      param = if term_node.predicate?
        :pred_uri 
      elsif term_node.object_term?
        :obj_uri
      end

      term_search_results_path(term_query: TermQuery.new({
        result_type: :record,
        filters: [
          TermQueryFilter.new(param => term_node.uri)
        ]
      }).to_params)
    else
      term_node.uri
    end

    redirect_to url, status: 302
  end
end
