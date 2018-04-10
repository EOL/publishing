# A TB Record is passed around as a hash. ...Thus these are really just class
# methods which are *passed* a hash. ...I'm not sure I like this and may change
# the code in the future to either extend the hash class itself or to force us
# to pass around Record instances instead of hashes. ..For now, though, this is
# simple enough.
class TraitBank
  class Record
    def self.iucn_status_key(record)
      unknown = "unknown"
      return unknown unless record && record[:object_term]
      Eol::Uris::Iucn.uri_to_code(record[:object_term][:uri]) || unknown
    end
  end
end
