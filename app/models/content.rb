module Content
  extend ActiveSupport::Concern

  included do
    belongs_to :provider, polymorphic: true # User or Resource
    belongs_to :language

    has_many :content_attributions, as: :content
    has_many :attributions, through: :content_attributions
    has_many :content_sections, as: :content
    has_many :sections, through: :content_sections
    has_many :page_contents, as: :content
    has_many :pages, through: :page_contents
    has_many :curations, through: :page_contents
    has_many :content_references, as: :content
    has_many :references, through: :content_references
  end
end
