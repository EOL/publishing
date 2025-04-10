require 'rake'

Rails.app_class.load_tasks

Crono.perform(WarmCacheJob).every 1.day, at: { hour: 3 }
Crono.perform(CommentsJob).every 1.day, at: { hour: 3, minute: 30 }
Crono.perform(CommentsJob).every 1.day, at: { hour: 13, minute: 30 }
Crono.perform(BriefSummaryWarmingJob).every 1.day, at: { hour: 0, minute: 0 }

# */10 * * * * /app/bin/unicorn_restart_if_mem >> /app/log/unicorn_restart.log 2>&1
# */5 * * * * /usr/sbin/logrotate /app/config/logrotate.conf >> /app/log/logrot.log 2>&1

Crono.perform(LogRotJob).every 5.minutes
Crono.perform(WarmCsvDownloadsJob).every 14.days, at: { hour: 1 }
Crono.perform(BuildIdentifierMapJob).every 1.month, on: :monday
Crono.perform(FixMediaCountsJob).every 1.month, on: :tuesday # if the media tab doesn't show up on a page but should ...
# TODO: diff these two files and see if they are actually the same thing!
Crono.perform(BuildFullIdentifierMapJob).every 1.month, on: :thursday
Crono.perform(BuildAllIdentifierMapsJob).every 1.month, on: :friday
Crono.perform(BuildMediaManifestJob).every 1.month, on: :friday
Crono.perform(BuildSitemapJob).every 1.month, on: :thursday, at: { hour: 19 }
Crono.perform(ReindexSearchkickJob).every 1.month, on: :friday, at: { hour: 19 }
Crono.perform(PreferredCommonNameJob).every 1.day, at: { hour: 19 }
Crono.perform(UserDownloadExpireOldJob).every 1.week, at: { hour: 18 }
Crono.perform(DescCountsJob).every 1.week, at: { hour: 17 }
Crono.perform(FixAllMissingNativeNodesJob).every 1.month, on: :friday
Crono.perform(TermNameTranslationDumpJob).every 1.week, on: :wednesday, at: { hour: 12 }
Crono.perform(RefreshPredCountsForWordcloudJob).every 1.week, on: :tuesday, at: { hour: 20 }
Crono.perform(TermStatUpdateJob).every 2.weeks, on: :monday, at: { hour: 20 }
Crono.perform(PageStatUpdateJob).every 2.weeks, on: :tuesday, at: { hour: 1 }
Crono.perform(UpdateTermNameI18nPropsJob).every 1.month, on: :monday, at: { hour: 12 }
