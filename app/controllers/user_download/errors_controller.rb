class UserDownload::ErrorsController < ApplicationController
  def show
    @download = UserDownload.find(params[:download_id])
    return render(status: :not_found) if !@download.failed? || @download.download_error.nil?
  end
end
