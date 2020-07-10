require 'rake'

Rails.app_class.load_tasks

Crono.perform(WarmCacheJob).every 1.day, at: { hour: 3 }
Crono.perform(CommentsJob).every 1.day, at: { hour: 3, minute: 30 }
Crono.perform(CommentsJob).every 1.day, at: { hour: 13, minute: 30 }
Crono.perform(LogRotJob).every 1.hours
Crono.perform(TermsJob).every 1.day, at: { hour: 2 }
Crono.perform(PredCountJob).every 1.day, at: { hour: 1 }
Crono.perform(WarmCsvDownloadsJob).every 14.days, at: { hour: 1 }
Crono.perform(BuildIdentifierMapJob).every 1.month, on: :monday
Crono.perform(BuildSitemapJob).every 1.month, on: :thursday, at: { hour: 19 }
Crono.perform(ReindexSearchkickJob).every 1.month, on: :tuesday, at: { hour: 19 }
Crono.perform(PreferredCommonNameJob).every 1.month, on: :wednesday, at: { hour: 19 }
Crono.perform(UserDownloadExpireOldJob).every 1.week, at: { hour: 18 }
Crono.perform(DescCountsJob).every 1.week, at: { hour: 17 }
Crono.perform(FixAllMissingNativeNodesJob).every 1.month, on: :friday
Crono.perform(TermNameTranslationDumpJob).every 1.week, on: :wednesday, at: { hour: 12 }
