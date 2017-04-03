class Resource < ActiveRecord::Base
  belongs_to :partner, inverse_of: :resources

  has_many :nodes, inverse_of: :resource
  has_many :articles, as: :provider
  has_many :links, as: :provider
  has_many :media, as: :provider

  enum publish_status: [ :unpublished, :publishing, :published, :deprecated ]

  class << self
    def native
      Rails.cache.fetch("resources/native") do
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
    end

    # Required to read the IUCN status
    def iucn
      Rails.cache.fetch("resources/iucn") do
        Resource.where(name: "IUCN Structured Data").first_or_create do |r|
          r.name = "IUCN Structured Data"
          r.partner = Partner.native
          r.description = "TBD"
          r.content_trusted_by_default = true
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end

    # Required to find the "best" Extinction Status: TODO: update the name when
    # we actually have the darn resource.
    def extinction_status
      Rails.cache.fetch("resources/extinction_status") do
        Resource.where(name: "Extinction Status").first_or_create do |r|
          r.name = "Extinction Status"
          r.partner = Partner.native
          r.description = "TBD"
          r.content_trusted_by_default = true
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end

    # Required to find the "best" Extinction Status:
    def paleo_db
      Rails.cache.fetch("resources/paleo_db") do
        Resource.where(name: "The Paleobiology Database").first_or_create do |r|
          r.name = "The Paleobiology Database"
          r.partner = Partner.native
          r.description = "TBD"
          r.content_trusted_by_default = true
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end
  end
end
