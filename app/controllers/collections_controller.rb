  class CollectionsController < ApplicationController
  layout "collections"

  before_filter :sanitize_collection_params
  before_filter :find_collection_with_pages, only: [:edit, :show]
  before_filter :find_collection, only: [:update, :destroy, :add_user, :remove_user]
  before_filter :user_able_to_edit_collection, only: [:edit]

  # TODO: You cannot do this without being logged in.
  def create
    # TODO: cleanup.
    Rails.logger.error("Hi there.")
    @collection = Collection.new(collection_params)
    @collection.users << current_user
    if @collection.save
      Rails.logger.error("SAved.")
      # This looks like it could be expensive on big collections. ...but
      # remember: this is a NEW collection. It will be fast:
      @collected = (@collection.collections + @collection.pages).first
      if @collected
        flash[:notice] = I18n.t(:collection_created_for_association,
          name: @collection.name, associated: @collected.name,
          link: collection_path(@collection))
        redirect_to @collected
      else
        flash[:notice] = I18n.t(:collection_created, name: @collection.name).html_safe
        redirect_to @collection
      end
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "new"
    end
  end

  def edit
  end

  def destroy
    authorize @collection
    name = @collection.name
    if @collection.destroy
      flash[:notice] = I18n.t("collection.destroyed", name: name)
      redirect_to current_user
    else
      # TODO: some kind of hint as to the problem, in a flash...
      redirect_to @collection
    end
  end

  def show
  end

  def update
    authorize @collection
    # This is obnoxious, but Rails can't handle deleting *associations* that
    # lack primary keys, so we do it manually:
    # TODO: later.
    # c_params = collection_params
    # if c_params["collected_pages_attributes"]
    #   c_params["collected_pages_attributes"].each do |index, collected_page|
    #
    #   end
    # end

    if @collection.update(collection_params)
      flash[:notice] = I18n.t("collection.updated")
      redirect_to @collection
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "edit"
    end
  end

  def add_user
    authorize @collection
    @user = User.find(params[:user_id])
    @collection.users << @user
    respond_to do |fmt|
      fmt.js {}
    end
  end

  def remove_user
    authorize @collection
    @user = User.find(params[:user_id])
    @collection.users.delete(@user)
    respond_to do |fmt|
      fmt.js {}
    end
  end

  private

  def find_collection_with_pages
    @collection = Collection.where(id: params[:id]).includes(:collection_associations).first
    @pages = CollectedPage.where(collection_id: @collection.id)
    case params[:sort]
    when "name"
      @pages = @pages.joins(page: :native_node).
        order("nodes.canonical_form#{params[:sort_dir] == "desc" ? " DESC" : ""}")
    when "sort"
      @pages = @pages.
        includes(page: [:preferred_vernaculars, :native_node]).
        order("annotation#{params[:sort_dir] == "desc" ? " DESC" : ""}")
    when "hierarchy"
      @pages = @pages.joins(page: :native_node).
        order("nodes.depth#{params[:sort_dir] == "desc" ? " DESC" : ""}, nodes.canonical_form")
    else
      @pages = @pages.
        includes(page: [:preferred_vernaculars, :native_node]).
        order("position")
    end
  end

  def find_collection
    @collection = Collection.where(id: params[:id] || params[:collection_id]).includes(:collection_associations,
      :collected_pages).first
  end

  def collection_params
    params.require(:collection).permit(:name, :description, :collection_type,
      collection_associations_attributes: [:associated_id],
      collected_pages_attributes: [:id, :page_id, :annotation,
        collected_pages_media_attributes: [:medium_id, :collected_page_id, :_destroy]])
  end

  def sanitize_collection_params
    params[:collection][:collection_type] = Collection.collection_types[params[:collection][:collection_type]] if params[:collection]
  end

  def user_able_to_edit_collection
    unless @collection && current_user.try(:can_edit_collection?,@collection)
      redirect_to collection_path(@collection), flash: { error:  I18n.t(:collection_unauthorized_edit) }
    end
    return true
  end
end
