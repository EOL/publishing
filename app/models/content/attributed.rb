# Content with a little more
module Content::Attributed
  extend ActiveSupport::Concern

  included do
    belongs_to :license
    belongs_to :location
    belongs_to :sytlesheet
    belongs_to :javascript
    belongs_to :bibliographic_citation
    belongs_to :provider, polymorphic: true # User or Resource

    has_many :attributions, as: :content
  end
end
