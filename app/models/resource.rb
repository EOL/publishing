class Resource
  include ActiveModel::Model
  
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
  

end