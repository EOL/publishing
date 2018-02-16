require 'rails_helper'

RSpec.describe TermQuery do
  it { should have_many(:numeric_filters) }
  it { should accept_nested_attributes_for(:numeric_filters) }
  it { should have_many(:range_filters) }
  it { should accept_nested_attributes_for(:range_filters) }
  it { should have_many(:object_term_filters) }
  it { should accept_nested_attributes_for(:object_term_filters) }
  it { should have_many(:predicate_filters) }
  it { should accept_nested_attributes_for(:predicate_filters) }
  it { should have_one(:user_download) }
end
