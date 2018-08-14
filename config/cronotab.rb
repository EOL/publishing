Crono.perform(WarmCacheJob).every 1.days, at: '3:00'
Crono.perform(CommentsJob).every 1.days, at: '3:30'
Crono.perform(LogRotJob).every 1.hours
