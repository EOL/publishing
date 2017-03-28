require "rails_helper"

describe PagesHelper do
  describe "#construct_summary" do
    let(:rank) { instance_double("Rank", name: "class") }
    let(:invisible_ancestor) { instance_double("Node", has_breadcrumb?: false) }
    let(:first_ancestor) { instance_double("Node", has_breadcrumb?: true,
      name: "boobars") }
    let(:an_ancestor) { instance_double("Node", has_breadcrumb?: true,
      name: "animal") }
    let(:penultimate_ancestor) { instance_double("Node", has_breadcrumb?: true,
      rank: rank, scientific_name: "Sci bar") }
    let(:last_ancestor) { instance_double("Node", has_breadcrumb?: true) }

    let(:node) do
      instance_double("Node", ancestors: [invisible_ancestor, first_ancestor,
        penultimate_ancestor, last_ancestor])
    end

    let(:node_with_an) do
      instance_double("Node", ancestors: [invisible_ancestor, an_ancestor,
        penultimate_ancestor, last_ancestor])
    end

    let(:top_node) do
      instance_double("Node", ancestors: [invisible_ancestor])
    end

    context "simple page" do
      let(:page) do
        instance_double("Page",
          native_node: node,
          name: "something",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: false,
          habitats: ""
        )
      end

      it "constructs a summary" do
        expect(helper.construct_summary(page)).
          to eq("Sci foo (something) is a boobar in the class Sci bar.")
      end
    end

    context "page with animal ancestor" do
      let(:page) do
        instance_double("Page",
          native_node: node_with_an,
          name: "something",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: false,
          habitats: ""
        )
      end

      it "uses 'an'" do
        expect(helper.construct_summary(page)).
          to match("an animal")
      end
    end

    context "page with no vernacular" do
      let(:page) do
        instance_double("Page",
          native_node: node_with_an,
          name: "Sci foo",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: false,
          habitats: ""
        )
      end

      it "has no parens" do
        expect(helper.construct_summary(page)).
          not_to match(/\(/)
      end
    end

    context "page with no ancestors" do
      let(:page) do
        instance_double("Page",
          native_node: top_node,
          name: "Sci foo",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: false,
          habitats: ""
        )
      end

      it "says it is top level" do
        expect(helper.construct_summary(page)).
          to match(/is a top-level classification/)
      end
    end

    context "extinct page" do
      let(:page) do
        instance_double("Page",
          native_node: top_node,
          name: "Sci foo",
          scientific_name: "Sci foo",
          is_it_extinct?: true,
          is_it_marine?: false,
          habitats: ""
        )
      end

      it "says it is extinct" do
        expect(helper.construct_summary(page)).
          to match(/This species is extinct/)
      end
    end

    context "marine page" do
      let(:page) do
        instance_double("Page",
          native_node: top_node,
          name: "Sci foo",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: true,
          habitats: ""
        )
      end

      it "says it is marine" do
        expect(helper.construct_summary(page)).
          to match(/It is marine/)
      end
    end

    context "page with habitats" do
      let(:page) do
        instance_double("Page",
          native_node: top_node,
          name: "Sci foo",
          scientific_name: "Sci foo",
          is_it_extinct?: true,
          is_it_marine?: true,
          habitats: "foo, bar, baz"
        )
      end

      it "says where it lives" do
        expect(helper.construct_summary(page)).
          to match(/It is found in bar, baz, and foo/)
      end
    end
  end
end
