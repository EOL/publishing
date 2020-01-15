# Content with a little more
module Content::Attributed
  extend ActiveSupport::Concern

  included do
    belongs_to :license
    belongs_to :location, optional: true
    belongs_to :sytlesheet, optional: true
    belongs_to :javascript, optional: true
    belongs_to :bibliographic_citation, optional: true
    belongs_to :provider, polymorphic: true, optional: true # User or Resource

    has_many :attributions, as: :content
  end
end
