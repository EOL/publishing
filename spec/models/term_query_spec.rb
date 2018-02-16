require 'rails_helper'

RSpec.describe TermQuery do
  it { should have_many(:numeric_filters) }
  it { should have_many(:range_filters) }
  it { should have_many(:object_term_filters) }
  it { should have_one(:user_download) }
end
