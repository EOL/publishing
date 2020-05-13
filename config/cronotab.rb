Crono.perform(WarmCacheJob).every 1.day, at: '3:00'
Crono.perform(CommentsJob).every 1.day, at: '3:30'
Crono.perform(CommentsJob).every 1.day, at: '13:30'
Crono.perform(LogRotJob).every 1.hours
Crono.perform(TermsJob).every 1.day, at: '2:00'
Crono.perform(PredCountJob).every 1.day, at: '1:00'
Crono.perform(WarmCsvDownloadsJob).every 1.day, at: '1:00'
