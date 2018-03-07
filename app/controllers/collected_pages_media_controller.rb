class CollectedPagesMediaController < ApplicationController
  layout "application"

  def destroy
    q = CollectedPagesMedium.
      where(collected_page_id: params[:collected_page_id],
        medium_id: params[:medium_id])
    @collected_pages_medium = q.first
    page = @collected_pages_medium.collected_page
    authorize page.collection
    if q.delete_all
      Collecting.create(user: current_user, collection: @collected_pages_medium.collected_page.collection,
        action: "remove", content: @collected_pages_medium.medium)
      respond_to do |fmt|
        fmt.html do
          flash[:notice] = I18n.t("collected_pages_medium.destroyed_flash")
          redirect_to @collected_page.collection
        end
        fmt.js { }
      end
    end
    # TODO: if it DIDN'T work... ummn... explain why?
  end

private

  def collected_page_params
    params.require(:collected_page).permit(:collection_id, :page_id, collected_pages_media_attributes: [:medium_id])
  end

  def existing_collected_page_params
    params.require(:collected_page).permit(:collection_id, :page_id)
  end

  def new_page_params
    params.permit(:page_id, medium_ids: [])
  end
end
