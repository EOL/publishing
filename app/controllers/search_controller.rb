class SearchController < ApplicationController
  def search
    # TODO: we'll want some whitelist filtering here later:
    # NOTE:
    @q = params[:q]
    # More later, but for now, we can just search names:
    @pages = Page.search(include: [:native_node, :preferred_vernaculars, :page_contents]) do
      # NOTE: @q DOES NOT WORK HERE (for some reason)
      if params[:q] =~ /\*$/
        any do
          fulltext params[:q] # params[:q]
          fulltext params[:q].sub(/\*$/, "")
        end
      else
        fulltext params[:q]
      end
      paginate page: params[:page] || 1, per_page: params[:per_page] || 30
    end

    respond_to do |fmt|
      fmt.html
      fmt.json { render json: JSON.pretty_generate(@pages.results.as_json(
        except: :native_node_id,
        methods: :scientific_name,
        include: {
          preferred_vernaculars: { only: [:string], include: { language: { only: :code } } },
          # NOTE I'm excluding a lot more for search than you would want for the basic page json:
          top_image: { only: [ :id, :guid, :owner, :name ],
            methods: [:small_icon_url, :medium_icon_url],
            include: { provider: { only: [:id, :name] } , license: { only: [:id, :name, :icon_url] } } }
        }
      )) }
    end
  end
end
