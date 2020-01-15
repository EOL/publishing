class PageRedirect < ApplicationRecord
  belongs_to :redirect_to, class_name: Page
end
