class SearchController < ApplicationController
  def search
    # TODO: we'll want some whitelist filtering here later:
    name = params[:q]
    # More later, but for now, we can just search names:
    @pages = Page.search do
      fulltext name
      paginate page: params[:page] || 1, per_page: params[:per_page] || 30
    end
  end
end
