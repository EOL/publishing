class PagesController < ApplicationController
  include DataAssociations
  before_action :set_media_page_size, only: [:show, :media]
  before_action :no_main_container
  after_filter :no_cache_json

  helper :data

  # See your environment config; this action should be ignored by logs.
  def ping
    if ActiveRecord::Base.connection.active?
      render text: 'pong'
    else
      render status: 500
    end
  end

  def autocomplete
    full_results = Page.autocomplete(params[:query])
    if params[:full]
      render json: full_results
    elsif params[:simple]
      simplified = full_results.map do |r|
          field = r['highlight']&.first&.first&.split('.').first
          name = r.send(field) || r.scientific_name
          if name.is_a?(Array)
            first_hit = name.grep(/#{params[:query]}/i)&.first
            name = first_hit || name.first
          end
          { name: name, title: name, id: r.id, url: page_path(r.id) }
        end
      simplified = { results: simplified } if params[:simple] == 'hash'
      render json: simplified
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

  # TODO: I suspect this method and its compatriots can be made redundant.
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
      fmt.js { render(layout: false) }
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
      "title" => "Comments on #{@page.rank&.name} #{name} page (#{@page.id})".gsub('  ', ' '),
      "category" => cat["id"],
      "tags[]" => "id:#{@page.id}", # sigh.
      "unlist_topic" => false,
      "is_warning" => false,
      "archetype" => "regular",
      "nested_post" => true,
      # NOTE: we do NOT want to translate this. The comments site is English.
      "raw" => "Please leave your comments regarding <a href='#{page_overview_path(@page)}'>#{name}</a> in this thread
        by clicking on REPLY below. If you have contents related to specific content please provide a specific URL. For
        additional information on how to use this discussion forum, <a href='http://discuss.eol.org/'>click here</a>."

    )
    client.show_tag("id:#{@page.id}")
    redirect_to Comments.post_url(post["post"])
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
    @page = PageDecorator.decorate(Page.find(params[:id]))
    @page_title = @page.name
    # get_media # NOTE: we're not *currently* showing them, but we will.
    # TODO: we should really only load Associations if we need to:
    build_associations(@page.data)
    # Required mostly for paginating the first tab on the page (kaminari
    # doesn't know how to build the nested view...)
    respond_to do |format|
      format.html {}
    end
  end

  def reindex
    raise "Unauthorized" unless is_admin?
    @page = Page.where(id: params[:page_id]).first
    @page.clear
    expire_fragment(page_data_path(@page))
    expire_fragment(page_details_path(@page))
    expire_fragment(page_classifications_path(@page))
    Rails.cache.delete("brief_summary/#{page.id}")
    flash[:notice] = t("pages.flash.reindexed")
    redirect_to page_overview_path(@page)
  end

  def data
    @page = PageDecorator.decorate(Page.where(id: params[:page_id]).first)
    @predicate = params[:predicate] ? @page.glossary[params[:predicate]] : nil
    @predicates = @predicate ? [@predicate[:uri]] : @page.predicates
    @resources = TraitBank.resources(@page.data)
    build_associations(@page.data)
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html do
        if request.xhr?
          render layout: false
        else
          render
        end
      end

      format.js {}
    end
  end

  def maps
    @page = PageDecorator.decorate(Page.where(id: params[:page_id]).first)
    # NOTE: sorry, no, you cannot choose the page size for maps.
    @media = @page.maps.by_page(params[:page]).per(18)
    @subclass = "map"
    @subclass_id = Medium.subclasses[:map]
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def media
    @page = PageDecorator.decorate(Page.where(id: params[:page_id]).first)
    return render(status: :not_found) unless @page # 404
    get_media
    respond_to do |format|
      format.html do
        if request.xhr?
          render :layout => false
        else
          render
        end
      end
    end
  end

  def articles
    @page = PageDecorator.decorate(Page.where(id: params[:page_id]).first)
    return render(status: :not_found) unless @page # 404
    @articles = @page.articles
                 .includes(:license, :resource)
                 .where(['page_contents.source_page_id = ?', @page.id]).references(:page_contents)
    respond_to do |format|
      format.html do
        if request.xhr?
          render :layout => false
        else
          render
        end
      end
    end
  end

  def classifications
    @page = Page.where(id: params[:page_id]).includes(:preferred_vernaculars, nodes: [:children, :page],
      native_node: [:children, node_ancestors: :ancestor]).first
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def details
    @page = PageDecorator.decorate(Page.where(id: params[:page_id]).includes(articles: [:license, :sections,
      :bibliographic_citation, :location, :resource, attributions: :role]).first)
    return render(status: :not_found) unless @page # 404
    respond_to do |format|
      format.html {}
      format.js {}
      format.json { render json: @page.articles } # TODO: add sections later.
    end
  end

  def names
    @page = PageDecorator.decorate(Page.where(id: params[:page_id]).includes(:preferred_vernaculars,
      :native_node, { vernaculars: :language }).first)
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

  def get_media
    if @page.media_count > 1000
      # Too many. Just use ALL of them for filtering:
      @licenses = License.all.pluck(:name).uniq.sort
      @subclasses = Medium.subclasses.keys.sort
      # List of resources, as of Jul 2018 (query takes about 32 seconds), that HAVE images, i.e.:
      # a = Medium.where(subclass: 0).select('resource_id').uniq('resource_id').pluck(:resource_id).sort
      # a.delete(0) ; puts a.join(',')
      resource_ids = [2,4,8,9,10,11,12,14,46,53,181,395,410,416,417,418,420,459,461,462,463,464,465,468,469,470,474,475,
        481,486,493,494,495,496,507,508]
      @resources = Resource.where(id: resource_ids).select('id, name').sort_by { |r| r.name.downcase }
    else
      @licenses = License.where(id: @page.media.pluck(:license_id).uniq).pluck(:name).uniq.sort
      @subclasses = @page.media.pluck(:subclass).uniq.map { |i| Medium.subclasses.key(i) }
      @resources = Resource.where(id: @page.media.pluck(:resource_id).uniq).select('id, name').sort
    end
    media = @page.media
                 .includes(:license, :resource, page_contents: { page: %i[native_node preferred_vernaculars] })
                 .where(['page_contents.source_page_id = ?', @page.id]).references(:page_contents)

    if params[:license]
      media = media.joins(:license).where(["licenses.name = ? OR licenses.name LIKE ?", params[:license], "#{params[:license]} %"])
      @license = params[:license]
    end
    if params[:subclass]
      @subclass = params[:subclass]
      media = media.where(subclass: params[:subclass])
    end
    if params[:resource_id]
      @resource_id = params[:resource_id].to_i
      media = media.where(['page_contents.resource_id = ?', @resource_id])
      @resource = Resource.find(@resource_id)
    end
    @media_count = media.limit(1000).count
    @media = media.by_page(params[:page]).per(@media_page_size).without_count
  end
end
