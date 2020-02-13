class TaxonomicStatus < ApplicationRecord
  has_many :scientific_names, inverse_of: :taxonomic_status

  class << self
    def preferred
      @preferred ||= where(name: "accepted").first_or_create do |ts|
        ts.name = "accepted"
        ts.is_preferred = true
      end
    end
    
    def synonym
      TaxonomicStatus.where(name: "synonym").first_or_create do |ts|
        ts.name = "synonym"
        ts.is_preferred = false
      end
    end
    
    def misnomer
      TaxonomicStatus.where(name: "misnomer").first_or_create do |ts|
        ts.name = "misnomer"
        ts.is_preferred = false
      end
    end

    def unusable
      TaxonomicStatus.where(name: "unusable").first_or_create do |ts|
        ts.name = "unusable"
        ts.is_preferred = false
      end
    end
  end

  # As of this writing, the following were the known "types":
  # | accepted                              | <- implies preferred
  # | accepted name                         | <- implies preferred
  # | acronym                               | <- synonym; implies virus
  # | alternate representation              | <- synonym
  # | ambiguous synonym                     | <- "not a real synonym," but still listed; never used to merge
  # | anamorph                              | <- alternative to preferred name (preferred if not associated w/ accepted name)
  # | authority                             | <-- REQUIRES INVESTIGATION
  # | basionym                              | <- synonym
  # | blast name                            | <- DO NOT IMPORT!
  # | database artifact                     | <- DO NOT IMPORT!
  # | equivalent name                       | <-- REQUIRES INVESTIGATION
  # | genbank acronym                       | <- synonym; implies virus
  # | genbank anamorph                      | <- alternative to preferred name (preferred if not associated w/ accepted name)
  # | genbank synonym                       | <- synonym
  # | genus synonym                         | <- synonym
  # | heterotypic synonym                   | <- synonym
  # | heterotypicSynonym                    | <- synonym
  # | homonym & junior synonym              | <-- REQUIRES INVESTIGATION
  # | homonym (illegitimate)                | <-- REQUIRES INVESTIGATION
  # | homotypic synonym                     | <- synonym
  # | horticultural                         | <-- REQUIRES INVESTIGATION
  # | illegitimate                          | <-- REQUIRES INVESTIGATION
  # | in-part                               | <-- REQUIRES INVESTIGATION
  # | includes                              | <-- REQUIRES INVESTIGATION
  # | incorrect authority information       | <- synonym
  # | incorrect spelling                    | <- synonym
  # | invalid                               | <- synonym
  # | invalidly published, nomen nudum      | <- synonym
  # | invalidly published, other            | <- synonym
  # | junior homonym                        | <-- REQUIRES INVESTIGATION
  # | junior synonym                        | <- synonym
  # | lexical variant                       | <- synonym
  # | misapplied                            | <- "not a real synonym," but still listed; never used to merge
  # | misapplied name                       | <- "not a real synonym," but still listed; never used to merge
  # | misnomer                              | <- "not a real synonym," but still listed; never used to merge
  # | misspelling                           | <- synonym
  # | nomen dubium                          | <- implies no hierarchy; "bad original description"; should be indicated on page
  # | nomen oblitum                         | <- synonym; "hasn't been used for a long time"
  # | not accepted                          | <- synonym
  # | objective synonym                     | <- synonym
  # | original name/combination             | <- synonym
  # | orthographic variant (misspelling)    | <- synonym
  # | orthographic variant                  | <- synonym
  # | other                                 | <-- REQUIRES INVESTIGATION
  # | other, see comments                   | <-- REQUIRES INVESTIGATION
  # | pro parte                             | <-- REQUIRES INVESTIGATION
  # | provisionally accepted name           | <- implies no hierarchy; should be indicated on page
  # | rejected name                         | <- synonym
  # | senior synonym                        | <- quite possibly the preferred name, otherwise synonym
  # | species inquirenda                    | <- implies no hierarchy; "a species of doubtful identity requiring further investigation"
  # | spelling alternative                  | <- synonym
  # | subjective synonym                    | <- synonym
  # | subsequent name/combination           | <- synonym
  # | superfluous renaming (illegitimate)   | <- synonym
  # | synonym                               | <- synonym
  # | synonym (objective = homotypic)       | <- synonym
  # | synonym (subjective = heterotypic)    | <- synonym
  # | teleomorph                            | <- alternative to preferred name (preferred if not associated w/ accepted name)
  # | type material                         | <-- REQUIRES INVESTIGATION
  # | unavailable name                      | <- synonym
  # | unavailable, database artifact        | <- DO NOT IMPORT!
  # | unavailable, incorrect orig. spelling | <- synonym
  # | unavailable, literature misspelling   | <- synonym
  # | unavailable, nomen nudum              | <- synonym
  # | unavailable                           | <- synonym
  # | unavailable, other                    | <- synonym
  # | unavailable, suppressed by ruling     | <- synonym
  # | uncertain                             | <-- REQUIRES INVESTIGATION
  # | unjustified emendation                | <- synonym
  # | unnecessary replacement               | <- synonym
  # | unpublished name                      | <- synonym
  # | unspecified in provided data          | <-- REQUIRES INVESTIGATION
  # | valid                                 | <- implies preferred
  # | valid name                            | <- implies preferred
end
