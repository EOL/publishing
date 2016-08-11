class Rank < ActiveRecord::Base
  # Obnoxiously, some of these terms are reserved, so ugly r_ to distinguish:
  enum treat_as: [ :r_domain, :r_kingdom, :r_phylum, :r_class, :r_order, :family, :genus, :species ]
end
