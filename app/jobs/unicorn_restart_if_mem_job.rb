class UnicornRestartIfMemJob < ApplicationJob
  def perform
    `#{Rails.root.join('bin', 'unicorn_restart_if_mem')} >> #{Rails.root.join('log', 'unicorn_restart.log')} 2>&1`
  end
end
