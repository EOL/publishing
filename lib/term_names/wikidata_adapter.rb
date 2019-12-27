require "http"

class TermNames::WikidataAdapter
  ID_CAPTURE_REGEX = /https?:\/\/www\.wikidata\.org\/wiki\/(?<id>Q\d+)/

  def self.name
    "wikidata"
  end

  def uri_regexp
    "https?:\/\/www\.wikidata\.org\/.*"
  end
end
