class ContentPartnerUser < ActiveRecord::Base
  has_many :users
  has_many :content_partners, foreign_key: "content_partner_id", class_name: "ContentPartner"
end
