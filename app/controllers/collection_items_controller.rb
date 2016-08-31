class CollectionItemsController < ActionController::Base
  layout "application"

  def new
    class_name = params[:item_type]
    # TODO: insecure. add whitelisting of class_name.
    klass = Object.const_get(class_name)
    @item = klass.send(:find, params[:item_id])
    @collection_item = CollectionItem.new(
      item: @item)
    @collection = Collection.new
    @collection.collection_items << @collection_item
    @bad_collection_ids = CollectionItem.where(
      item_type: @collection_item.item_type, item_id: @collection_item.item_id).
      pluck(:collection_id)
  end
end
