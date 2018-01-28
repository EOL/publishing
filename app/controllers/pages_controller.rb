class PagesController < ApplicationController

  before_action :set_media_page_size, only: [:show, :media]

  after_filter :no_cache_json

  helper :data
  helper_method :get_associations

  def autocomplete
    full_results = Page.autocomplete(params[:query])
    if params[:full]
      render json: full_results
    else
      render json: {
        results: full_results.map do |r|
          name = r.scientific_name
          vern = r.preferred_vernacular_strings.first
          name += " (#{vern})" unless vern.blank?
          { title: name, url: page_path(r.id), image: r.icon, id: r.id }
        end,
        action: { url: "/search?q=#{params[:query]}",
          text: t("autocomplete.see_all", count: full_results.total_entries) }
      }
    end
  end

  def topics
    client = Comments.discourse
    @topics = client.latest_topics
    respond_to do |fmt|
      fmt.js { }
    end
  end

  def comments
    @page = Page.where(id: params[:page_id]).first
    client = Comments.discourse
    return nil unless client.respond_to?(:categories)
    # TODO: we should configure the name of this category:
    cat = client.categories.find { |c| c["name"] == "EOL Pages" }
    # TODO: we should probably create THAT ^ it if it's #nil?
    @url = nil
    @count = begin
      tag = client.show_tag("id:#{@page.id}")
      topic = tag["topic_list"]["topics"].first
      if topic.nil?
        0
      else
        @url = "#{Comments.discourse_url}/t/#{topic["slug"]}/#{topic["id"]}"
        topic["posts_count"]
      end
    rescue DiscourseApi::NotFoundError
      0
    end
    respond_to do |fmt|
      fmt.js { }
    end
  end

  def create_topic
    @page = Page.where(id: params[:page_id]).first
    client = Comments.discourse
    name = @page.name == @page.scientific_name ?
      "#{@page.scientific_name}" :
      "#{@page.scientific_name} (#{@page.name})"
    # TODO: we should configure the name of this category:
    cat = client.categories.find { |c| c["name"] == "EOL Pages" }

    # It seems their API is broken insomuch as you cannot use their
    # #create_topic method AND add tags to it. Thus, I'm just calling the raw
    # API here:
    # TODO: rescue this and look for the existing post (again) and redirect there.
    post = client.post("posts",
      "title" => "Comments on #{@page.rank.try(:name)} #{name} page",
      "category" => cat["id"],
      "tags[]" => "id:#{@page.id}", # sigh.
      "unlist_topic" => false,
      "is_warning" => false,
      "archetype" => "regular",
      "nested_post" => true,
      # TODO: looks like this link is broken?
      # NOTE: we do NOT want to translate this. The comments site is English.
      "raw" => "Please leave your comments regarding <a href='#{pages_url(@page)}'>#{name}</a> in this thread by clicking on REPLY below. If you have contents related to specific content please provide a specific URL. For additional information on how to use this discussion forum, <a href='http://discuss.eol.org/'>click here</a>."
    )
    client.show_tag("id:#{@page.id}")
    redirect_to "#{Comments.discourse_url}/t/#{post["post"]["topic_slug"]}/#{post["post"]["topic_id"]}"
  end

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
      fmt.html do
        Rails.cache.delete("pages/index/stats")
        # This is overkill (we only want to clear the data count, not e.g. the
        # glossary), but we want to be overzealous, not under:
        TraitBank::Admin.clear_caches
        Rails.logger.warn("LANDING PAGE STATS CLEARED.")
        flash[:notice] = t("landing_page.stats_cleared")
        redirect_to("/")
      end
    end
  end

  # This is effectively the "overview":
  def show
    @page = Page.where(id: params[:id]).first
    return render(status: :not_found) unless @page # 404
    @page_title = @page.name
    get_media
    # TODO: we should really only load Associations if we need to:
    get_associations
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
        @page.clear
        expire_fragment(page_data_path(@page))
        expire_fragment(page_details_path(@page))
        expire_fragment(page_classifications_path(@page))
      end
    end
  end

  # TODO: Decide whether serving the subtabs from here is actually RESTful.

  # TODO: Remove duplication with show (be mindful of id / page_id).
  def overview
    @page = Page.where(id: params[:page_id]).preloaded.first
    return render(status: :not_found) unless @page # 404
    @page_title = @page.name
    # TODO: we should really only load Associations if we need to:
    get_associations
    # Required mostly for paginating the first tab on the page (kaminari
    # doesn't know how to build the nested view...)
    respond_to do |format|
      format.html { render :show }
      format.js {}
    end
  end

  def data
    @page = Page.where(id: params[:page_id]).first
    return render(status: :not_found) unless @page # 404
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

  def no_cache_json
    # Prevents the back button from returning raw JSON
    if request.xhr?
      response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
    end
  end

  def set_media_page_size
    @media_page_size = 24
  end

  def get_associations
    @associations =
      begin
        ids = @page.data.map { |t| t[:object_page_id] }.compact.sort.uniq
        Page.where(id: ids).
          includes(:medium, :preferred_vernaculars, native_node: [:rank])
      end
  end

  def get_media
    #not working
    #media = @page.media.includes(:license, :resource)
    media = @page.media
    #params can't include paramaters in if conditionals
    # if params[:license]
      # media = media.joins(:license).
        # where(["licenses.name LIKE ?", "#{params[:license]}%"])
      # @license = params[:license]
    # end
    debugger
    media=media.joins(:license)
    debugger
    if params[:subclass_id]
      media = media.where(subclass: params[:subclass_id])
      @subclass_id = params[:subclass_id].to_i
      @subclass = Medium.subclasses.find { |n, id| id == @subclass_id }[0]
    end
    if params[:resource_id]
      media = media.where(resource_id: params[:resource_id])
      @resource_id = params[:resource_id].to_i
      result = ResourceApi.get_resource_using_id(@resource_id)
      @resource = Resource.new(name: result["name"],origin_url: result["original_url"],uploaded_url: result["uploaded_url"],
                      type: result["type"],path: result["path"],last_harvested_at: result["last_harvested_at"],harvest_frequency: result["harvest_frequency"],
                      day_of_month: result["day_of_month"],nodes_count: result["nodes_count"],position: result["position"],is_paused: result["_paused"],
                      is_approved: result["_approved"],is_trusted: result["_trusted"],is_autopublished: result["_autopublished"],is_forced: result["_forced"],
                      dataset_license: result["dataset_license"],dataset_rights_statement: result["dataset_rights_statement"],
                      dataset_rights_holder: result["dataset_rights_holder"],default_license_string: result["default_license_string"],
                      default_rights_statement: result["default_rights_statement"],default_rights_holder: result["default_rights_holder"],
                      default_language_id: result["default_language_id"])
      #@resource = Resource.find(@resource_id)
    end
    @media = media.page(params[:page]).per_page(@media_page_size)
    @page_contents = PageContent.where(content_type: "Medium", content_id: @media.map(&:id))
  end
end
