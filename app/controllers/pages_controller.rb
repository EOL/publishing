class PagesController < ApplicationController

  before_action :set_media_page_size, only: [:show, :media]

  helper :traits

  def index
    @title = I18n.t("landing_page.title")
    @stats = Rails.cache.fetch("pages/index/stats", expires_in: 1.week) do
      {
        pages: Page.count,
        data: TraitBank.count,
        media: Medium.count,
        articles: Article.count,
        users: User.active.count,
        collections: Collection.count
      }
    end
    render layout: "head_only"
  end

  def clear_index_stats
    respond_to do |fmt|
      fmt.js do
        Rails.cache.delete("pages/index/stats")
        # This is overkill (we only want to clear the trait count, not e.g. the
        # glossary), but we want to be overzealous, not under:
        TraitBank.clear_caches
        Rails.logger.warn("LANDING PAGE STATS CLEARED.")
      end
    end
  end

  # This is effectively the "cover":
  def show
    @page = Page.where(id: params[:id]).preloaded.first
    return render(status: :not_found) unless @page # 404
    @page_title = @page.name
    get_media
    # TODO: we should really only load Associations if we need to:
    get_associations
    @topic = get_topic
    # Required mostly for paginating the first tab on the page (kaminari
    # doesn't know how to build the nested view...)
    respond_to do |format|
      format.html {}
    end
  end

  def reindex
    respond_to do |fmt|
      fmt.js do
        @page = Page.where(id: params[:page_id]).first
        @page.reindex
      end
    end
  end

  # TODO: Decide whether serving the subtabs from here is actually RESTful.

  # TODO: Remove duplication with show (be mindful of id / page_id).
  def cover
    @page = Page.where(id: params[:page_id]).preloaded.first
    return render(status: :not_found) unless @page # 404
    @page_title = @page.name
    get_media
    # TODO: we should really only load Associations if we need to:
    get_associations
    # Required mostly for paginating the first tab on the page (kaminari
    # doesn't know how to build the nested view...)
    respond_to do |format|
      format.html { render :show }
      format.js {}
    end
  end

  def traits
    @page = Page.where(id: params[:page_id]).first
    return render(status: :not_found) unless @page # 404
    @resources = TraitBank.resources(@page.traits)
    get_associations
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def maps
    @page = Page.where(id: params[:page_id]).first
    # NOTE: sorry, no, you cannot choose the page size for maps.
    @media = @page.maps.page(params[:page]).per_page(18)
    @subclass = "map"
    @subclass_id = Medium.subclasses[:map]
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def media
    @page = Page.where(id: params[:page_id]).first
    return render(status: :not_found) unless @page # 404
    get_media
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def classifications
    # TODO: can't preload ancestors, eeeesh.
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars,
      :nodes, native_node: :children).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def details
    @page = Page.where(id: params[:page_id]).includes(articles: [:license, :sections,
      :bibliographic_citation, :location, :resource, attributions: :role]).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
      format.json { render json: @page.articles } # TODO: add sections later.
    end
  end

  def names
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars,
      :native_node).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def literature_and_references
    # NOTE: I'm not sure the preloading here works because of polymorphism.
    @page = Page.where(id: params[:page_id]).includes(referents: :parent).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def breadcrumbs
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars,
      :nodes, native_node: :children).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.js {}
    end
  end

private

  def set_media_page_size
    @media_page_size = 24
  end

  def get_associations
    @associations =
      begin
        ids = @page.traits.map { |t| t[:object_page_id] }.compact.sort.uniq
        # TODO: include more when we need it
        Page.where(id: ids).
          includes(:medium, :preferred_vernaculars, native_node: [:rank])
      end
  end

  def get_media
    @media = @page.media.includes(:license)
    if params[:license]
      @media = @media.joins(:license).
        where(["licenses.name LIKE ?", "#{params[:license]}%"])
      @license = params[:license]
    end
    if params[:subclass_id]
      @media = @media.where(subclass: params[:subclass_id])
      @subclass_id = params[:subclass_id].to_i
      @subclass = Medium.subclasses.find { |n, id| id == @subclass_id }[0]
    end
    if params[:resource_id]
      @media = @media.where(resource_id: params[:resource_id])
      @resource_id = params[:resource_id].to_i
      @resource = Resource.find(@resource_id)
    end
    # TODO: #per broke for some reason; fix:
    @media = @media.page(params[:page]).per_page(@media_page_size)
  end
  
  def get_topic
     topic = CLIENT.search("#{request.url}")
     topic['topics'].first['id'] unless topic['topics'].nil?
  end
end
