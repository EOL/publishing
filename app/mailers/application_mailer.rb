class ApplicationMailer < ActionMailer::Base
  default from: "no-reply-domain@eol.org"
  layout 'mailer'
end
