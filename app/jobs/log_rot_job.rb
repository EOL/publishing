class LogRotJob < ApplicationJob
  def perform
    `logrotate #{Rails.root.join('config', 'logrotate.conf')}`
  end
end
