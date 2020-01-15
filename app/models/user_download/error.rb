class UserDownload::Error < ApplicationRecord
  belongs_to :user_download, inverse_of: "download_error"
end
