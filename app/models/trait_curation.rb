class TraitCuration < ActiveRecord::Base
  belongs_to :user

  enum trust: [ :unreviewed, :trusted, :untrusted ]
end
