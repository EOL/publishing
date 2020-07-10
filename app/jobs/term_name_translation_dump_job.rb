class TermNameTranslationDumpJob < ApplicationJob
  def perform
    Rails.logger.info("START TermNameTranslationDumpJob")
    TermNames::Dumper.dump
    Rails.logger.info("END TermNameTranslationDumpJob")
  end
end
