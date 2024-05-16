# Be sure to restart your server when you modify this file.

Rails.backtrace_cleaner.add_silencer { |line| /puma|activesupport|actionpack|rack|railties|lograge/.match?(line) }

# You can remove all the silencers if you're trying to debug a problem that might stem from framework code.
# Rails.backtrace_cleaner.remove_silencers!
