class UserDownloadsController < ApplicationController
  def show
    download = UserDownload.find(params[:id])
    file = TraitBank::DataDownload.path.join(download.filename)
    # TODO: we should steal the "nice" name from the view helper, and rename the file.
    send_file(file, filename: download.filename, type: "text/tab-separated-values")
  end
end
