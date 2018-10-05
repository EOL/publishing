class CollectionAssociationsController < ApplicationController
  layout "application"

  def new
    redirect_to new_user_session_path unless current_user
    @collection_association = CollectionAssociation.new(new_associated_params)
    @associated = @collection_association.associated
    @collection = Collection.new
    @collection.collection_associations << @collection_association
    # NOTE: this looks at ALL collections, rather than just the users. I
    # *suspect* (but may well be wrong) that this is fast enough, given how rare
    # duplication is across collections. ...But we might try join()ing with
    # collections that the user has access to. ...That's two tables, though, so
    # I'm avoiding it in the name of simplicity (and, again, because I'm not
    # sure the cost of the joins would be gained by the selection of the user).
    @bad_collection_ids = CollectionAssociation.where(
      associated_id: @collection_association.associated_id).
      pluck(:collection_id)
  end

  def create
    # TODO: Access control
    @collection_association = CollectionAssociation.new(collection_association_params)
    if @collection_association.save
      Collecting.create(user: current_user, action: "add",
        collection: @collection_association.collection,
        associated_collection: @collection_association.associated)
      flash[:notice] = I18n.t(:collection_association_added_to_collection,
        name: @collection_association.collection.name,
        associated: @collection_association.associated.name,
        link: collection_path(@collection_association.collection))
      redirect_to @collection_association.associated
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "new"
    end
  end

  def destroy
    @collection_association = CollectionAssociation.find(params[:id])
    authorize @collection_association.collection
    associated = @collection_association.associated
    if @collection_association.destroy
      Collecting.create(user: current_user, collection: @collection_association.collection,
        action: "remove", associated_collection: associated)
      flash[:notice] = I18n.t("collection_associations.destroyed_flash", name: associated.name)
    end
    redirect_to @collection_association.collection
  end

  private

  def collection_association_params
    params.require(:collection_association).permit(:collection_id, :associated_id)
  end

  def new_associated_params
    params.permit(:associated_id)
  end
end
