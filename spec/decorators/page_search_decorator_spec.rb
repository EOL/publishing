require "rails_helper"

RSpec.describe PageSearchDecorator do
  describe "#hierarchy" do
    before do
      a1 = create(:node, :canonical_form => "a1") 
      allow(a1).to receive(:use_breadcrumb?) { true } 
      a2 = create(:node, :canonical_form => "a2")
      allow(a2).to receive(:use_breadcrumb?) { true } 
      a3 = create(:node, :canonical_form => "a3")
      allow(a3).to receive(:use_breadcrumb?) { true } 
      a_ignore = create(:node, :canonical_form => "doesn't matter")
      allow(a_ignore).to receive(:use_breadcrumb?) { false }
      node_ancestors = [a3, a_ignore, a2, a_ignore, a_ignore, a1].map do |a| 
        create(:node_ancestor, :ancestor => a)
      end
      page = create(:empty_page)
      native = create(:native_node, :node_ancestors => node_ancestors, :page => page)
      page.native_node = native
      page.save
      @decorator = PageSearchDecorator.decorate(page)
    end

    it "returns the expected result" do
      expect(@decorator.hierarchy).to eql("a3/…/a2/…/a1")
    end
  end
end
