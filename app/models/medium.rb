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
  enum subclass: [ :image, :video, :sound, :map, :js_map ] # NOTE: "map" implies "image map".
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

  # NOTE: this is temp code, for use ONCE. If you're reading this, i've probably already run it and you can
  # probably already delete it.
  class << self
    def fix_wikimedia_attributes(start_row = 1)
      dbg('STARTING')
      resource = Resource.find_by_name('Wikimedia Commons')
      # :identifier, :term_name, :agent_role, :term_homepage
      agents_file = Rails.root.join('public', 'data', 'wikimedia', 'agent.tab')
      # :subtype, :access_uri, :usage_terms, :owner, :agent_id
      media_file = Rails.root.join('public', 'data', 'wikimedia', 'media_resource.tab')
      @agents = slurp(agents_file, :identifier)
      @media = slurp(media_file, :access_uri)
      @roles = {}
      Role.all.each { |role| @roles[role.name.downcase] = role.id }
      @licenses = {}
      License.all.each { |lic| @licenses[lic.source_url.downcase] = lic.id }
      dbg('Looping through media...')
      total_media = @media.keys.size
      last_row = 0
      begin
        @media.keys.each_with_index do |access_uri, i|
          next if i < start_row
          last_row = i+1
          dbg(".. now on medium #{i+1}/#{total_media} (#{access_uri})") if i == start_row || (i % 100).zero?
          row = @media[access_uri]
          agents = []
          unless row[:agent_id].blank?
            row[:agent_id].split(/;\s*/).each do |agent_id|
              if @agents.has_key?(agent_id)
                agents << @agents[agent_id].merge(identifier: agent_id)
              else
                puts "Missing agent #{agent_id} for row #{access_uri}; Skipping..."
              end
            end
          end
          medium = Medium.where(resource_id: resource.id, source_url: access_uri)
          if medium.empty?
            puts "NOT FOUND: Medium #{access_uri}#{row[:subtype].blank? ? '' : " (MAP)"}! Skipping row..."
            next
          end
          medium = medium.first
          unless row[:subtype].blank?
            # The ONLY value we have in there (as of this writing) is "map"
            medium.subclass = :map
          end
          medium.attributions.delete_all
          agents.each do |agent|
            # :identifier, :term_name, :agent_role, :term_homepage
            role_id = if @roles.has_key?(agent[:agent_role])
                        @roles[agent[:agent_role]]
                      else
                        dbg("Unknown agent role: #{agent[:agent_role]}; using 'contributor'.")
                        @roles['contributor']
                      end
            attribution = Attribution.create(content_id: medium.id, content_type: 'Medium', role_id: role_id,
              value: agent[:term_name], url: agent[:term_homepage], resource_id: resource.id,
              content_resource_fk: agent[:identifier])
            medium.attributions << attribution
          end
          medium.owner = row[:owner]
          if row[:usage_terms]
            if @licenses.has_key?(row[:usage_terms])
              medium.license_id = @licenses[row[:usage_terms]]
            else
              dbg("Unknown license: #{row[:usage_terms]} skipping...")
            end
          end
          medium.save
        end
      rescue => e
        dbg("** ERROR! Ended on row #{last_row}: #{e.to_s}")
      end
    end

    def slurp(file, key)
      dbg("slurping #{file} ...")
      require 'csv'
      # NOTE: I tried the "headers: true" and "forgiving" mode or whatever it was called, but it didn't work. The
      # quoting in this file is really non-conformant (there's one line where there are TWO sets of quotes and that
      # breaks), so I'm just using this "cheat" that I found online where it uses a null for a quote, and I'm building
      # my own hash (inefficiently, but we don't care):
      all_data = CSV.read(file, col_sep: "\t", quote_char: "\x00")
      keys = all_data.shift
      keys.map! { |key| key.underscore.downcase.to_sym }
      hash = {}
      all_data.each do |row|
        row_hash = Hash[keys.zip(row)]
        identifier = row_hash.delete(key)
        raise "DUPLICATE IDENTIFIER! #{identifier}" if hash.has_key?(identifier)
        hash[identifier] = row_hash
      end
      hash
    end

    # NOTE: temp code for fix_wikimedia_attributes
    def dbg(msg)
      puts "[#{Time.now.strftime('%F %T')}] #{msg}"
      @last_flush = Time.now
      STDOUT.flush
    end
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

  def sound_url
    # TODO:
    '#'
  end

  def video_url
    # TODO:
    '#'
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
