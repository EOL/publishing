class Notification < ApplicationMailer
  def send_email(user, subject, mail_body)
    @user = user
    @body = mail_body
    mail(to: @user.email, subject: subject) 
  end
end
