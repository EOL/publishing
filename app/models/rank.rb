class Rank < ActiveRecord::Base
  enum treat_as: [ :domain, :kingdom, :phylum, :class, :order, :family, :genus, :species ]
end
