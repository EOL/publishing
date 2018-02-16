require 'rails_helper'

RSpec.describe TermQuery do
  it { should have_many(:filters).class_name("TermQueryFilter") }
  it { should have_one(:user_download) }
end
