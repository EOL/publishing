require 'rails_helper'

RSpec.describe ContentPartners::ResourcesController do
  context "creating new resource" do
    render_views
    #let (:resource){Resource.new}
    it "should re-render new template on failed save"do
      #Resource.any_instance.stubs(:valid?).returns(false)
      Resource.any_instance.stub(:errors).and_return(["can't be blank"])
      post :create , content_partner_id: 1
      #expect(response.body).to render_template()
      #responds.should render_template('new')
    end
  end
end