class Map < ActiveRecord::Base
  include Content
  include Content::Attributed
end
