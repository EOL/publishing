class GbifDownloadsController < ApplicationController
  before_action :require_admin

  def create
    query = TermQuery.find_or_save!(TermQuery.new(term_query_params))
    download = GbifDownload.create(
      user: current_user,
      term_query: query
    )

    message = if download 
                download.background_build_with_delay
                "GBIF download job created -- check your user profile page to view its status"
              else
                logger.error("Failed to create GBIF download")
                logger.error(download.errors.full_messages)
                "An unexpected error occurred"
              end

    redirect_to request.referer, notice: message
  end

  private
  def term_query_params
    params.require(:term_query).permit(TermQuery.expected_params)
  end
end
