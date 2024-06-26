require "http"
require "nokogiri"

class TermNames::GeonamesAdapter
  include TermNames::ResponseCheck

  ID_CAPTURE_REGEX = /https?:\/\/www\.geonames\.org\/(?<id>\d+)/
  BASE_URL = "http://api.geonames.org/get"
  APP_ID = Rails.application.config.x.geonames_app_id

  def initialize(options)
    @storage = TermNames::NameStorage.new
  end

  def self.name
    "geonames"
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
      next if !check_response(response)

      xml = Nokogiri(response.to_s)

      locales.each do |locale|
        locale_nodes = xml.at_xpath("//alternateName[@lang='#{locale}']")
        next if !locale_nodes
        first_node = locale_nodes.is_a?(Array) ? locale_nodes.first : locale_nodes
        @storage.set_value_for_locale(locale, uri, first_node.text)
      end

      sleep 1 # throttle api calls
    end
  end

  def names_for_locale(locale)
    @storage.names_for_locale(locale)
  end
end

