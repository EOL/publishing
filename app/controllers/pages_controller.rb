class PagesController < ApplicationController

  before_action :set_media_page_size, only: [:show, :media]

  helper :traits

  def index
    @title = I18n.t("landing_page.title")
    @stats = Rails.cache.fetch("pages/index/stats", expires_in: 1.week) do
      {
        pages: Page.count,
        data: TraitBank.trait_count,
        media: Medium.count,
        articles: Article.count,
        users: User.count,
        collections: Collection.count
      }
    end
    render layout: "head_only"
  end

  def show
    @page = Page.where(id: params[:id]).preloaded.first
    return render(status: :not_found) unless @page # 404
    @page_title = @page.name
    get_media
    if @media.empty?
      # We are going to show traits instead of media!
      @resources = TraitBank.resources(@page.traits)
    end
    get_associations
    # Required mostly for paginating the first tab on the page (kaminari
    # doesn't know how to build the nested view...)
    respond_to do |format|
      format.html {}
      # TODO: you have to tell it which tab was first, sadly... This won't work
      # if there are no media, but paginatable traits. Really, we need to fix
      # the problem with kaminari. ATM it's fine because we only paginate media,
      # but we want to paginate other things!
      format.js { render action: :media }
    end
  end

  # TODO: Decide whether serving the subtabs from here is actually RESTful.

  def traits
    @page = Page.where(id: params[:page_id]).first
    return render(status: :not_found) unless @page # 404
    @resources = TraitBank.resources(@page.traits)
    get_associations
    respond_to do |format|
      format.js {}
    end
  end

  def maps
    @page = Page.where(id: params[:page_id]).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.js {}
    end
  end

  def media
    @page = Page.where(id: params[:page_id]).first
    return render(status: :not_found) unless @page # 404
    get_media
    respond_to do |format|
      format.js {}
    end
  end

  def classifications
    # TODO: can't preload ancestors, eeeesh.
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars,
      :nodes, native_node: :children).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.js {}
    end
  end

  def details
    @page = Page.where(id: params[:page_id]).includes(articles: [:license, :sections,
      :bibliographic_citation, :location, :resource, attributions: :role]).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.js {}
      format.json { render json: @page.articles } # TODO: add sections later.
    end
  end

  def names
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars,
      :native_node).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.js {}
    end
  end

  def literature_and_references
    # NOTE: I'm not sure the preloading here works because of polymorphism.
    @page = Page.where(id: params[:page_id]).includes(referents: :parent).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
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
          includes(:medium, :native_node, :preferred_vernaculars)
      end
  end

  def get_media
    @media = @page.media.includes(:license)
    @license = nil
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
end
