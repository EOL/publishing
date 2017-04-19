require "rails_helper"

describe PagesHelper do
  let(:rank_sp) { instance_double("Rank", name: "species") }
  let(:rank_g) { instance_double("Rank", name: "genus") }
  let(:rank_fam) { instance_double("Rank", name: "family") }

  describe "#construct_summary" do
    let(:rank_class) { instance_double("Rank", name: "class") }
    let(:invisible_ancestor) { instance_double("Node", has_breadcrumb?: false) }
    let(:first_ancestor) { instance_double("Node", has_breadcrumb?: true,
      name: "boobars") }
    let(:an_ancestor) { instance_double("Node", has_breadcrumb?: true,
      name: "animal") }
    let(:penultimate_ancestor) { instance_double("Node", has_breadcrumb?: true,
      rank: rank_class, scientific_name: "Sci bar") }
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
          id: 1,
          native_node: node,
          name: "something",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: false,
          habitats: "",
          rank: rank_sp,
          species_count: 123
        )
      end

      it "constructs a summary" do
        expect(helper.construct_summary(page)).
          to eq("Sci foo (something) is a boobar in the class Sci bar.")
      end

      it "does NOT count species" do
        expect(helper.construct_summary(page)).
          not_to match /has 123 species/
      end
    end

    context "page with animal ancestor" do
      let(:page) do
        instance_double("Page",
          id: 1,
          native_node: node_with_an,
          name: "something",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: false,
          habitats: "",
          rank: rank_sp
        )
      end

      it "uses 'an'" do
        expect(helper.construct_summary(page)).
          to match("an animal")
      end
    end

    context "higher-level page" do
      let(:page) do
        instance_double("Page",
          id: 1,
          native_node: node_with_an,
          name: "something",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: false,
          habitats: "",
          rank: rank_class
        )
      end

      it "should be blank" do
        expect(helper.construct_summary(page)).
          to be_blank
      end
    end

    context "genus-level page" do
      let(:page) do
        instance_double("Page",
          id: 1,
          native_node: node_with_an,
          name: "something",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: false,
          habitats: "",
          rank: rank_g,
          species_count: 123
        )
      end

      it "should count species" do
        expect(helper.construct_summary(page)).
          to match /it has 123 species/i
      end
    end

    context "page with no vernacular" do
      let(:page) do
        instance_double("Page",
          id: 1,
          native_node: node_with_an,
          name: "Sci foo",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: false,
          habitats: "",
          rank: rank_sp
        )
      end

      it "has no parens" do
        expect(helper.construct_summary(page)).
          not_to match(/\(/)
      end
    end

    context "extinct page" do
      let(:page) do
        instance_double("Page",
          id: 1,
          native_node: top_node,
          name: "Sci foo",
          scientific_name: "Sci foo",
          is_it_extinct?: true,
          is_it_marine?: false,
          habitats: "",
          rank: rank_sp
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
          id: 1,
          native_node: top_node,
          name: "Sci foo",
          scientific_name: "Sci foo",
          is_it_extinct?: false,
          is_it_marine?: true,
          habitats: "",
          rank: rank_sp
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
          id: 1,
          native_node: top_node,
          name: "Sci foo",
          scientific_name: "Sci foo",
          is_it_extinct?: true,
          is_it_marine?: true,
          habitats: "foo, bar, baz",
          rank: rank_sp
        )
      end

      it "says where it lives" do
        expect(helper.construct_summary(page)).
          to match(/It is found in bar, baz, and foo/)
      end
    end
  end
end
