class Article < ActiveRecord::Base
  include Content
  include Content::Attributed

  alias_attribute :description, :body

  has_many :references, as: :parent
  has_many :referents, through: :references

  DEFAULT_LANG_CODE = "eng"

  def lang_or_default
    language ? language : Language.find_by(code: DEFAULT_LANG_CODE)
  end

  def first_section
    @first_section ||= sections.sort_by { |s| s.position }.first
  end

  def first_section_sort_order
    first_section&.position || 9999
  end

  def self.fix_quotes
    # owner: "\"<a href=\"\"http://www.nps.gov/plants.sos/\"\">USDI BLM</a>. United States, UT. 2003.\""
    count = 0
    Searchkick.disable_callbacks
    puts "Starting"
    STDOUT.flush
    Article.where('body LIKE "\"%" OR owner LIKE "\"%" OR name LIKE "\"%"').find_each do |m|
      m.body = clean_val(m.body)
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
    return nil if val.nil?
    val.gsub(/""+/, '"').gsub(/^\s+/, '').gsub(/\s+$/, '').gsub(/^\"\s*(.*)\s*\"$/, '\\1')
  end

  def sortable_name
    'ZZZZ' if name.blank?
    name
  end
end
