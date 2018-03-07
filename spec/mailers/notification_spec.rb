require "rails_helper"

RSpec.describe Notification, type: :mailer do
  describe '.send_email' do
    let(:user) { FactoryGirl.create(:user)}
    let(:mail) {Notification.send_email(user,"Test_Subject","Test_body").deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq('Test_Subject')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([user.email])
    end

    it 'renders the sender email' do
      expect(mail.from).to eq(['no-reply-domain@eol.org'])
    end

    it 'assigns a username' do
      expect(mail.body.encoded).to match(user.username)
    end

    it 'assigns a body' do
      expect(mail.body.encoded).to match('Test_body')
    end
  end
end 
