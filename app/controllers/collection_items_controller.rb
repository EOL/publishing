class CollectionItemsController < ApplicationController
  layout "application"

  def new
    @collection_item = CollectionItem.new(new_item_params)
    @item = @collection_item.item
    @collection = Collection.new
    @collection.collection_items << @collection_item
    @bad_collection_ids = CollectionItem.where(
      item_type: @collection_item.item_type, item_id: @collection_item.item_id).
      pluck(:collection_id)
  end

  def create
    @collection_item = CollectionItem.new(collection_item_params)
    if @collection_item.save
      flash[:notice] = I18n.t(:collection_item_added_to_collection,
        name: @collection_item.collection.name,
        item: @collection_item.item.name,
        link: collection_path(@collection_item.collection))
      redirect_to @collection_item.item
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "new"
    end
  end

  private

  def collection_item_params
    params.require(:collection_item).permit(:collection_id, :item_type, :item_id)
  end

  def new_item_params
    params.permit(:item_id, :item_type)
  end
end
