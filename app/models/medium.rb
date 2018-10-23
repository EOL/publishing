# TODO: unmodified URL is probably not required; it's currently unused. ...Maybe delete it? Maybe use it. Not sure.
class Medium < ActiveRecord::Base
  include Content
  include Content::Attributed

  # Yes, we store this in two places. First, we log who set the icon when:
  has_many :page_icons, inverse_of: :medium
  # And then we denormlize the latest so we can query it efficiently:
  has_many :pages, inverse_of: :medium
  has_many :collected_pages_media, inverse_of: :medium
  has_many :collected_pages, through: :collected_pages_media
  has_many :collections, through: :collected_pages

  has_one :image_info, inverse_of: :image

  # NOTE: these MUST be kept in sync with the harvester codebase! Be careful. Sorry for the conflation.
  enum subclass: [ :image, :video, :sound, :map, :js_map ]
  enum format: [ :jpg, :youtube, :flash, :vimeo, :mp3, :ogg, :wav, :mp4 ]

  scope :images, -> { where(subclass: :image) }
  scope :videos, -> { where(subclass: :video) }
  scope :sounds, -> { where(subclass: :sound) }

  # NOTE: No, there is NOT a counter_culture here for pages, as this object does NOT reference pages itself.

  # searchable do
  #   text :name, :boost => 6.0
  #   text :description, :boost => 2.0
  #   text :resource_pk
  #   text :owner
  #   integer :ancestor_ids, multiple: true do
  #
  #   end
  # end

  def self.fix_quotes
    # owner: "\"<a href=\"\"http://www.nps.gov/plants.sos/\"\">USDI BLM</a>. United States, UT. 2003.\""
    count = 0
    rids = [2, 8, 11, 12, 53, 181, 395, 410, 417, 418, 420, 459, 462, 464, 468, 475, 486, 496, 511, 528, 529, 530, 540, 561, 563, 573, 594]
    Searchkick.disable_callbacks
    puts "Starting"
    STDOUT.flush
    Medium.where(resource_id: rids).where('description LIKE "\"%" OR owner LIKE "\"%" OR name LIKE "\"%"').find_each do |m|
      m.description = clean_val(m.description)
      m.owner = clean_val(m.owner)
      m.name = clean_val(m.name)
      if m.changed?
        m.save
        count += 1
        puts "... #{count}" if (count % 1000).zero?
        STDOUT.flush
      end
    end
    Searchkick.enable_callbacks
  end

  def self.clean_val(val)
    val.gsub(/""+/, '"').gsub(/^\s+/, '').gsub(/\s+$/, '').gsub(/^\"\s*(.*)\s*\"$/, '\\1')
  end

  def source_pages
    if page_contents.loaded? && page_contents.first&.association(:page)&.loaded?
      page_contents.select { |pc| pc.source_page_id == page_id }.map(&:page)
    else
      page_contents.includes(page: %i[native_node preferred_vernaculars]).sources.map(&:page)
    end
  end

  # TODO: we will have our own media server with more intelligent names:
  def original_size_url
    orig = Rails.configuration.x.image_path['original']
    ext = Rails.configuration.x.image_path['ext']
    base_url + "#{orig}#{ext}"
  end

  def large_size_url
    base_url + format_image_size(580, 360)
  end

  def medium_icon_url
    base_url + format_image_size(130, 130)
  end
  alias_method :icon, :medium_icon_url

  def medium_size_url
    base_url + format_image_size(260, 190)
  end

  # Drat. :S
  def name(language = nil)
    self[:name]
  end

  def small_size_url
    base_url + format_image_size(98, 68)
  end

  def small_icon_url
    base_url + format_image_size(88, 88)
  end

  def format_image_size(w, h)
    join = Rails.configuration.x.image_path['join']
    by = Rails.configuration.x.image_path['by']
    ext = Rails.configuration.x.image_path['ext']
    "#{join}#{w}#{by}#{h}#{ext}"
  end

  def vitals
    [name, "#{license.name} #{owner.html_safe}"]
  end

  def extra_search_data
    {
      :subclass => subclass
    }
  end
end
