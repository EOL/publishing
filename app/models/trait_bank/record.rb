# A TB Record is passed around as a hash. ...Thus these are really just class
# methods which are *passed* a hash. ...I'm not sure I like this and may change
# the code in the future to either extend the hash class itself or to force us
# to pass around Record instances instead of hashes. ..For now, though, this is
# simple enough.
class TraitBank
  class Record
    def self.obj_term_uri(record)
      record.dig(:object_term, :uri)
    end

    def self.obj_term_name(record)
      record.dig(:object_term, :name)
    end

    def self.source(record)
      record[:source]
    end
  end
end
