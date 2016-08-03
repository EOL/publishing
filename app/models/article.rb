class Article < ActiveRecord::Base
  include Content::Attributed
end
