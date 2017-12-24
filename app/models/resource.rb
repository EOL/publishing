class Resource
  include ActiveModel::Model
  # belongs_to :partner, inverse_of: :resources
# 
  # has_many :nodes, inverse_of: :resource
  # has_many :scientific_names, inverse_of: :resource
  # has_many :articles, as: :provider
  # has_many :links, as: :provider
  # has_many :media, as: :provider
   #missing bibliographic citation, description, resource data options

  attr_accessor :id, :name, :origin_url, :resource_data_set, :description,:type, :uploaded_url ,:path, :last_harvested_at, :harvest_frequency, :day_of_month, :nodes_count,
                :position, :is_paused, :is_approved, :is_trusted, :is_autopublished, :is_forced, :dataset_license,
                :dataset_rights_statement, :dataset_rights_holder, :default_license_string, :default_rights_statement,
                :default_rights_holder, :default_language_id, :harvests, :created_at, :updated_at, :flag 
                
  validates_presence_of :name, :type 
  validates_presence_of :uploaded_url, if: :is_url?
  validates_presence_of :path, if: :is_file?, if: :flag 
  #validates :type , presence:{message: "please select resource dataset" }
  #validates :type, inclusion: ["url","file"]
  #validates :type , :presence => {:if => 'type.nil?'}
  
  validates_length_of :name , maximum: 255
  validates_length_of :uploaded_url , allow_blank: true , allow_nil: true  , maximum: 255
  validates_length_of :path , allow_blank: true , allow_nil: true  , maximum: 255
  validates_length_of :description , allow_blank: true , allow_nil: true , maximum: 255
  validates_length_of :default_rights_holder, allow_blank: true , allow_nil: true , maximum: 255
  validates_length_of :default_rights_statement, allow_blank: true , allow_nil: true , maximum: 400
  
  #validates_format_of :uploaded_url , with: URI::regexp(%w(http https)), if: :is_url?
  #validates_format_of :uploaded_url , with: /(\.xml(\.gz|\.gzip)|\.tgz|\.zip|\.xls|\.xlsx|\.tar\.(gz|gzip))?/ , if: :is_url?
  #validates_format_of :path , with:  /(\.tar\.(gz|gzip)|\.tgz|\.zip)/ , if: :is_file?
  
  def is_url?
    type.eql?("url")
  end
  
  def is_file?
    type.eql?("file")
  end

  class << self
    def native
      Rails.cache.fetch("resources/native") do
        where(name: "Dynamic Working Hierarchy").first_or_create do |r|
          r.name = "Dynamic Working Hierarchy"
          r.partner = Partner.native
          r.description = "A synthesis of the hierarchies from EOL's trusted "\
            "partners, to be used for browsing eol.org"
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
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end
  
 
  end

end