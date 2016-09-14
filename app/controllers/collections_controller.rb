class CollectionsController < ApplicationController
  layout "collections"

  before_filter :find_collection, only: [:edit, :show, :update]

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
          name: @collection.name, item: item.name)
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
    if @collection.update(collection_update_params)
      flash[:notice] = I18n.t(:collection_updated)
      redirect_to @collection
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "edit"
    end
  end

  private

    def find_collection
      @collection = Collection.find(params[:id])
    end

    def collection_params
      params.require(:collection).permit(:name, collection_items_attributes: [:item_type, :item_id])
    end

    def collection_update_params
      params.require(:collection).permit(:name, :description)
    end
end
