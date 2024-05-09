# Be sure to restart your server when you modify this file.

# You can add backtrace silencers for libraries that you're using but don't wish to see in your backtraces.
Rails.backtrace_cleaner.add_silencer { |line| /puma /.match?(line) }
Rails.backtrace_cleaner.add_silencer { |line| /activesupport /.match?(line) }
Rails.backtrace_cleaner.add_silencer { |line| /actionpack /.match?(line) }
Rails.backtrace_cleaner.add_silencer { |line| /rack /.match?(line) }
Rails.backtrace_cleaner.add_silencer { |line| /railties /.match?(line) }
Rails.backtrace_cleaner.add_silencer { |line| /lograge /.match?(line) }

# You can also remove all the silencers if you're trying to debug a problem that might stem from framework code.
# Rails.backtrace_cleaner.remove_silencers!
