class UserDownloadsController < ApplicationController
  def show
    download = UserDownload.find(params[:id])
    send_file("#{Rails.root}/public/#{download.filename}",
      filename: download.filename, # TODO: we should steal the "nice" name from the helper.
      type: "text/tab-separated-values")
  end
end
