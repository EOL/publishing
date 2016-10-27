class CollectedPagesController < ApplicationController
  layout "application"

  def new
    @collected_page = CollectedPage.new(new_page_params)
    @page = @collected_page.page
    @wants_icon = ! @collected_page.media.empty?
    @collection = Collection.new(collected_pages: [@collected_page])
    @bad_collection_ids = CollectedPage.where(page_id: @page.id).
      pluck(:collection_id)
  end

  def create
    @collected_page = CollectedPage.find_or_initialize_by(existing_collected_page_params)
    if @collected_page.update(collected_page_params)
      flash[:notice] = I18n.t(:collected_page_added_to_collection,
        name: @collected_page.collection.name,
        page: @collected_page.page.name,
        link: collection_path(@collected_page.collection))
      redirect_to @collected_page.page
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "new"
    end
  end

  def search
    pages = CollectedPage.find_page(params[:q],
     params[:collection_id]).results.map(&:page)
    respond_to do |format|
         # TODO: JSON results for other types!
      format.json do
        render json: JSON.pretty_generate(pages.as_json(
          except: :native_node_id,
          methods: :scientific_name,
          include: {
            preferred_vernaculars: { only: [:string],
              include: { language: { only: :code } } },
            # NOTE I'm excluding a lot more for search than you would want for
            # the basic page json:
            top_image: { only: [ :id, :guid, :owner, :name ],
              methods: [:small_icon_url, :medium_icon_url],
              include: { provider: { only: [:id, :name] },
                license: { only: [:id, :name, :icon_url] } } }
          }
        ))
      end
    end
  end

  def search_results
    collected_pages = CollectedPage.find_page(params[:q],
    params[:collection_id]).results
    respond_to do |format|
      format.html {render partial: 'search_results', locals: {collected_pages: collected_pages, q: params[:q] }}
    end
  end
  private

  def collected_page_params
    params.require(:collected_page).permit(:collection_id, :page_id, collected_pages_media_attributes: [:medium_id])
  end

  def existing_collected_page_params
    params.require(:collected_page).permit(:collection_id, :page_id)
  end

  def new_page_params
    params.permit(:page_id, medium_ids: [])
  end
end
