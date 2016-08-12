class Article < ActiveRecord::Base
  include Content
  include Content::Attributed
end
