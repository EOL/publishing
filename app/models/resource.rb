class Resource < ActiveRecord::Base
  belongs_to :partner, inverse_of: :resources

  has_many :nodes, inverse_of: :resource
  has_many :articles, as: :provider
  has_many :links, as: :provider
  has_many :media, as: :provider

  enum publish_status: [ :unpublished, :publishing, :published, :deprecated ]

  class << self
    def native
      where(name: "Dynamic Working Hierarchy").first_or_create do |r|
        r.name = "Dynamic Working Hierarchy"
        r.partner = Partner.native
        r.description = "A synthesis of the hierarchies from EOL's trusted "\
          "partners, to be used for browsing eol.org"
        r.content_trusted_by_default = true
        r.is_browsable = true
        r.has_duplicate_nodes = false
      end
    end

    # Required to read the IUCN status
    def iucn
      @@iucn ||= Resource.where(name: "IUCN Structured Data").first
    end
  end
end
