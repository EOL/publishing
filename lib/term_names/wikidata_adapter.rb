require "http"

class TermNames::WikidataAdapter
  ID_CAPTURE_REGEX = /https?:\/\/www\.wikidata\.org\/wiki\/(?<id>Q\d+)/
  BASE_URL = "http://www.wikidata.org/wiki/Special:EntityData/"

  def self.name
    "wikidata"
  end

  def initialize
    @by_locale = {}
  end

  def uri_regexp
    "https?:\/\/www\.wikidata\.org\/.*"
  end

  def preload(uris, locales)
    [uris.first].each do |uri|
      id = (matches = uri.match(ID_CAPTURE_REGEX)) ? matches[:id] : nil
      next if id.nil?

      response = HTTP.follow.get(BASE_URL + id + ".json")

      if !response.status.success?
        puts "Got a bad response!"
        puts "Status: #{response.code}"
        puts "Body: #{response.body}"
        puts "Skipping..."
        next 
      end

      labels_by_locale = response.parse.dig("entities", id, "labels")

      locales.each do |locale|
        value = labels_by_locale.dig(locale.to_s, "value")
        next if value.nil?
        set_value_for_locale(locale, uri, value) 
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

