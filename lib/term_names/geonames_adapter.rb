require "http"
require "nokogiri"

class TermNames::GeonamesAdapter
  ID_CAPTURE_REGEX = /https?:\/\/www\.geonames\.org\/(?<id>\d+)/
  BASE_URL = "http://api.geonames.org/get"

  #TODO: move to secrets BEFORE MERGE
  APP_ID = Rails.application.config.x.geonames_app_id

  def initialize
    @by_locale = {}
  end

  def name
    "Geonames"
  end

  def uri_regexp
    "https?:\/\/www\.geonames\.org\/.*"
  end

  def ensure_app_id
    if APP_ID.blank?
      raise "You must set a geonames_app_id in secrets.yml!"
    end
  end

  def preload(uris, locales)
    ensure_app_id

    uris.each do |uri|
      id = (matches = uri.match(ID_CAPTURE_REGEX)) ? matches[:id] : nil
      next if id.nil?

      response = HTTP.get(BASE_URL, params: { geonameId: id, username: APP_ID})

      if !response.status.success?
        puts "Got a bad response!"
        puts "Status: #{response.code}"
        puts "Body: #{response.body}"
        puts "Skipping..."
        next 
      end

      xml = Nokogiri(response.to_s)

      locales.each do |locale|
        locale_nodes = xml.at_xpath("//alternateName[@lang='#{locale}']")
        next if !locale_nodes
        first_node = locale_nodes.is_a?(Array) ? locale_nodes.first : locale_nodes
        set_value_for_locale(locale, uri, first_node.text)
      end
    end
  end

  def names_for_locale(locale)
    raw_result = values_for_locale(locale)
    raw_result.collect do |k,v|
      TermNames::Result.new(k, v)
    end
  end

  private
  def set_value_for_locale(locale, uri, value)
    values_for_locale(locale)[uri] = value
  end

  def values_for_locale(locale)
    @by_locale[locale] ||= {}
    @by_locale[locale]
  end 
end

