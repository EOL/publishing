class PagesController < ApplicationController

  helper :traits

  def show
    @page = Page.where(id: params[:id]).preloaded.first
    raise "404" unless @page
    @page_title = @page.name
    @media = @page.media.includes(:license).page(params[:page])
    @resources = TraitBank.resources(@page.traits)

    @associations =
      begin
        ids = @page.traits.map { |t| t[:object_page_id] }.compact.sort.uniq
        # TODO: include more when we need it
        Page.where(id: ids).includes(:medium, :native_node, :preferred_vernaculars)
      end
  end

  # TODO: move; this should be more RESTful.
  def traits
    @page = Page.where(id: params[:page_id]).first
    respond_to do |format|
      format.js {}
    end
  end

  # TODO: move
  def article
    @page = Page.where(id: params[:page_id]).includes(articles: [:license, :sections,
      :bibliographic_citation, :location, :resource, attributions: :role]).first
    respond_to do |format|
      format.js {}
    end
  end

  # TODO: move; this should be more RESTful.
  def maps
    @page = Page.where(id: params[:page_id]).first
    respond_to do |format|
      format.js {}
    end
  end

  # TODO: move; this should be more RESTful.
  def classifications
    # TODO: can't preload ancestors, eeeesh.
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars,
      :nodes, native_node: :children).first
    respond_to do |format|
      format.js {}
    end
  end

  # TODO: move; this should be more RESTful.
  def details
    @page = Page.where(id: params[:page_id]).includes(articles: [:license, :sections,
      :bibliographic_citation, :location, :resource, attributions: :role]).first
    respond_to do |format|
      format.js {}
    end
  end

  # TODO: move; this should be more RESTful.
  def names
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars,
      :native_node).first
    respond_to do |format|
      format.js {}
    end
  end

  def literature_and_references
    # NOTE: I'm not sure the preloading here works because of polymorphism.
    @page = Page.where(id: params[:page_id]).includes(referents: :parent).first
    respond_to do |format|
      format.js {}
    end
  end

  def breadcrumbs
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars,
      :nodes, native_node: :children).first
    respond_to do |format|
      format.js {}
    end
  end

end
