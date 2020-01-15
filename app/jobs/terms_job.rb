class TermsJob < ApplicationJob
  def perform
    Rails.logger.warn("START Terms Sync")
    pub_log = Publishing.sync # Yes, overlap. That's fine.
    Rails.logger.warn("END Terms Sync, see ImportLog.find(#{pub_log&.logger&.id})")
    Rails.logger.warn("START Terms Parent/Child Relationships")
    log = []
    count = TraitBank::Terms::Relationships.fetch_parent_child_relationships(log)
    Rails.logger.warn("END Terms Parent/Child Relationships: loaded #{count}.")
    Rails.logger.warn("START Term Synonym Relationships")
    count = TraitBank::Terms::Relationships.fetch_synonyms(log)
    Rails.logger.warn("END Term Synonym Relationships: loaded #{count}.")
    Rails.logger.warn("START Term Units")
    count = TraitBank::Terms::Relationships.fetch_units(log)
    Rails.logger.warn("END Term Units: loaded #{count} predicate/unit relationships. Log:")
    Rails.logger.warn("START Terms Log:")
    log.each { |l| Rails.logger.warn(l) }
    Rails.logger.warn("END Terms Log:")
  end
end
