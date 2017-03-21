class PagesController < ApplicationController

  before_action :set_media_page_size, only: [:show, :media]

  helper :traits

  def show
    @page = Page.where(id: params[:id]).preloaded.first
    raise "404" unless @page
    @page_title = @page.name
    @media = @page.media.includes(:license).page(params[:page]).per(@media_page_size)
    # TODO: extract this (and again from #traits)
    @associations =
      begin
        ids = @page.traits.map { |t| t[:object_page_id] }.compact.sort.uniq
        # TODO: include more when we need it
        Page.where(id: ids).includes(:medium, :native_node, :preferred_vernaculars)
      end
      # Required mostly for paginating the first tab on the page (kaminari doesn't know how to build the nested view...)
      respond_to do |format|
        format.html {}
        # TODO: you have to tell it which tab was first, sadly... This won't
        # work if there are no media, but paginatable traits. Really, we need to
        # fix the problem with kaminari.
        format.js { render action: :media }
      end
  end

  # TODO: move; this should be more RESTful.
  def traits
    @page = Page.where(id: params[:page_id]).first
    @resources = TraitBank.resources(@page.traits)

    @associations =
      begin
        ids = @page.traits.map { |t| t[:object_page_id] }.compact.sort.uniq
        # TODO: include more when we need it
        Page.where(id: ids).includes(:medium, :native_node, :preferred_vernaculars)
      end
    respond_to do |format|
      format.js {}
      format.json { render json: { glossary: @page.glossary, traits: @page.grouped_traits } }
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
  def media
    @page = Page.where(id: params[:page_id]).first
    @media = @page.media.includes(:license).page(params[:page]).per(@media_page_size)
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
      format.json { render json: @page.articles } # TODO: add sections later.
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

private

  def set_media_page_size
    @media_page_size = 24
  end

end
