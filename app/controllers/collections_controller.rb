class CollectionsController < ApplicationController
  layout "collections"

  before_filter :find_collection_with_pages, only: [:edit, :show]
  before_filter :find_collection, only: [:update]

  # TODO: You cannot do this without being logged in.
  def create
    # TODO: cleanup.
    @collection = Collection.new(collection_params)
    @collection.users << current_user
    if @collection.save
      if @collection.collection_items.empty?
        flash[:notice] = I18n.t(:collection_created, name: @collection.name)
        redirect_to @collection
      else
        item = @collection.collection_items.first.item
        flash[:notice] = I18n.t(:collection_created_for_item,
          name: @collection.name, item: item.name,
          link: collection_path(@collection))
        redirect_to item
      end
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "new"
    end
  end

  def edit
  end

  def show
  end

  def update
    authorize @collection
    pp collection_params
    if @collection.update(collection_params)
      flash[:notice] = I18n.t(:collection_updated)
      redirect_to @collection
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "edit"
    end
  end

  private

  def find_collection_with_pages
    @collection = Collection.where(id: params[:id]).includes(:collection_items,
      collected_pages: { page: :preferred_vernaculars }).first
  end

  def find_collection
    @collection = Collection.where(id: params[:id]).includes(:collection_items,
      :collected_pages).first
  end

  # { "name" => "A", "description" => "B", "collected_pages_attributes" => { "0" => {
  # "id" => "3", "medium_ids" => ["6", "7", "8"], "medium_id" => "5" } } }
  def collection_params
    params.require(:collection).permit(:name, :description,
      collection_items_attributes: [:item_type, :item_id],
      collected_pages_attributes: [:id, :medium_id, medium_ids: []])
  end
end
