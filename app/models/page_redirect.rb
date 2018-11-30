class PageRedirect < ActiveRecord::Base
  belongs_to :redirect_to, class_name: Page
end
