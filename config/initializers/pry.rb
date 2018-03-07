# Stolen from https://blog.bugsnag.com/production-pry/
# Show red environment name in pry prompt
old_prompt = Pry.config.prompt
env = Pry::Helpers::Text.red(Rails.env.upcase)
Pry.config.prompt = [
  proc { |*a| "#{env} #{old_prompt.first.call(*a)}" },
  proc { |*a| "#{env} #{old_prompt.second.call(*a)}" }
]
