class CollectionsController < ActionController::Base
  # TODO: You cannot do this without being logged in.
  def create
    # TODO: cleanup.
    @collection = Collection.new(collection_params)
    @collection.users << current_user
    # TODO: Why is this happening?
    if @collection.save
      if @collection.collection_items.create
        if @collection.collection_items.empty?
          raise "You should not have gotten here; there should be an item."
          flash[:notice] = I18n.t(:collection_created, name: @collection.name)
          redirect_to @collection
        else
          item = @collection.collection_items.first.item
          flash[:notice] = I18n.t(:collection_created_for_item,
            name: @collection.name, item: item.collect_as)
          redirect_to item
        end
      else
        # TODO: some kind of hint as to the problem, in a flash...
        render "new"
      end
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "new"
    end
  end

  private

    def collection_params
      params.require(:collection).permit(:name, collection_items_attributes: [:item_type, :item_id])
    end
end
