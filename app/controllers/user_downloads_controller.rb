class UserDownloadsController < ApplicationController
  before_action :require_admin, only: :pending

  def pending
    @downloads = UserDownload.pending.order(created_at: :desc)
  end

  def show
    download = UserDownload.find(params[:id])
    
    if (!download.status.nil? && !download.completed?) || download.filename.nil?
      raise ActiveRecord::RecordNotFound.new("Not found") 
    end

    file = TraitBank::DataDownload.path.join(download.filename)
    # TODO: we should steal the "nice" name from the view helper, and rename the file.
    send_file(file, filename: download.filename, type: "text/tab-separated-values")
  end
end

