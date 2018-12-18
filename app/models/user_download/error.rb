class UserDownload::Error < ActiveRecord::Base
  belongs_to :user_download, inverse_of: "download_error"
end
