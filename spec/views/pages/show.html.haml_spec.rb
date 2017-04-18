require "rails_helper"

RSpec.describe "pages/show" do
  let(:resource) do
    create(:resource, id: 64333, name: "Short Res Name", url: nil)
  end
  let(:lic1) do
    instance_double("License", name: "Image license name")
  end
  let(:lic2) do
    instance_double("License", name: "Image2 LicName")
  end
  let(:image1) do
    instance_double("Medium", license: lic1, owner: "(c) Owner 1", id: 1,
      large_size_url: "some_url_580_360.jpg", medium_size_url: "img1_med.jpg",
      small_icon_url: "no_matter", original_size_url: "img1_full_size.jpg",
      name: "Awesome First Image")
  end
  let(:image2) do
    instance_double("Medium", license: lic2, owner: "&copy; Owner 2", id: 2,
      small_icon_url: "no_matter", original_size_url: "img2_full_size.jpg",
      large_size_url: "second_url_580_360.jpg", medium_size_url: "img2_med.jpg",
      name: "Great Second Image")
  end
  let(:rank) { create(:rank) }

  # NOTE: I think we'll eventually want to extract this into a nice class to
  # mock pages for views... but ATM we only need it once, here, so I'm leaving
  # it despite its gross size and complexity:
  let(:page) do
    ancestor = instance_double("Node", ancestors: [], name: "Ancestor Name",
      canonical_form: "Ancestor Canon", page_id: 653421, has_breadcrumb?: true, rank: rank, scientific_name: "Ancestor Sci")
    invisible_ancestor = instance_double("Node", ancestors: [ancestor], name: "InvisibleAncestor Name",
      canonical_form: "InvisibleAncestor Canon", page_id: 653421, has_breadcrumb?: false, rank: rank, scientific_name: "InvisibleAncestor Sci")
    parent = instance_double("Node", ancestors: [ancestor, invisible_ancestor], name: "Parent Name",
      canonical_form: "Parent Canon", page_id: 653421, has_breadcrumb?: true, rank: rank, scientific_name: "Parent Sci")
    node = instance_double("Node", ancestors: [ancestor, invisible_ancestor, parent], name: "SomeTaxon",
      children: [], resource: resource, has_breadcrumb?: true)
    lic2 = instance_double("License", name: "Article license name")
    article = instance_double("Article", name: "Article Name", license: lic2,
      body: "Article body", owner: "Article owner", rights_statement: nil,
      bibliographic_citation: nil, location: nil, attributions: [],
      source_url: nil, resource: resource, resource_pk: "1234")
    sci_name = instance_double("ScientificName", node: node,
      italicized: "<i>Nice scientific</i>",
      taxonomic_status: TaxonomicStatus.synonym)
    vernacular = instance_double("Vernacular", string: "something common",
      language: Language.english, is_preferred?: true, node: node,
      is_preferred_by_resource: true)
    traits = [
      { predicate: { uri: "http://predic.ate/one", name: "Predicate One" },
        measurement: "657", units: { uri: "http://un.its/one",
        name: "Units URI" }, resource_id: resource.id },
      { predicate: { uri: "http://predic.ate/one", name: "Predicate One" },
        object_term: { uri: "http://te.rm/one", name: "Term URI" } },
      { predicate: { uri: "http://predic.ate/two", name: "Uri" },
        literal: "literal trait value" } ]
    glossary = {
      "http://predic.ate/one" => { name: "Predicate One" },
      "http://predic.ate/two" => { name: "Predicate Two" },
      "http://un.its/one" => { name: "Units URI" },
      "http://te.rm/one" => { name: "Term URI" }
    }

    instance_double("Page",
      id: 8293,
      articles: [article],
      articles_count: 1,
      nodes_count: 1,
      glossary: glossary,
      grouped_traits: traits.group_by { |t| t[:predicate][:uri] },
      habitats: "",
      iucn_status_key: :lc,
      is_it_extinct?: false,
      is_it_marine?: false,
      literature_and_references_count: 3,
      map?: false,
      media_count: 2,
      nodes: [node],
      name: vernacular.string,
      names_count: 2,
      native_node: node,
      occurrence_map?: false,
      predicates: traits.map { |t| t[:predicate][:uri] },
      scientific_name: sci_name.italicized,
      scientific_names: [sci_name],
      top_image: image1,
      traits: traits,
      traits_count: 3,
      vernaculars: [vernacular],
      richness: 0,
      page_contents_count: 0,
      links_count: 0,
      maps_count: 0,
      vernaculars_count: 0,
      scientific_names_count: 0,
      referents_count: 0,
      species_count: 0,
      updated_at: Time.now
    )
  end

  before do
    assign(:page, page)
    media = [image1, image2]
    allow(media).to receive(:total_pages) { 1 } # kaminari
    allow(media).to receive(:current_page) { 1 } # kaminari
    allow(media).to receive(:limit_value) { 2 } # kaminari
    assign(:media, media)
    assign(:resources, { resource.id => resource })
  end

  it "shows the title" do
    render
    expect(rendered).to match "Something Common"
    expect(rendered).to match "Nice scientific"
  end

  context "with the media subtab showing" do

    before { render }

    it "shows the image names" do
      expect(rendered).to match image1.name
      expect(rendered).to match image2.name
    end

    it "shows the image medium icon" do
      # NOTE: I had a much fancier #have_tag implementation here, but it was
      # failing with "expected [HTML] to respond to `has_tag?`" ...and I
      # couldn't fix it. Easier to just move on right now. This will do.
      expect(rendered).to match image1.medium_size_url
      expect(rendered).to match image2.medium_size_url
    end

    it "shows the image original size (modal)" do
      expect(rendered).to match image1.original_size_url
      expect(rendered).to match image2.original_size_url
    end

    # NOTE: implementation as of this writing:
    # image.owner.html_safe.sub(/^\(c\)\s+/i, "").sub(/^&copy;\s+/i, "")
    it "shows the image owner" do
      expect(rendered).to match "Owner 1"
      expect(rendered).to match "Owner 2"
    end

    # Note: this is a weak test. Each
    it "shows the license name" do
      expect(rendered).to match lic1.name
      expect(rendered).to match lic2.name
    end

    it "shows the trust state" # TODO (we haven't implemented this yet)

    it "has a link to make exemplar (but NOT the first image!)" do
      expect(rendered).not_to have_link(href: page_icons_path(page_id: page.id, medium_id: image1.id))
      expect(rendered).to have_link(href: page_icons_path(page_id: page.id, medium_id: image2.id))
    end

    it "has a link to add to collection" do
      expect(rendered).to have_link(href: new_collected_page_path(page_id: page.id, medium_ids: [image1.id]))
      expect(rendered).to have_link(href: new_collected_page_path(page_id: page.id, medium_ids: [image2.id]))
    end

    it "has a link to the image page" do
      expect(rendered).to have_link(href: medium_path(image1))
      expect(rendered).to have_link(href: medium_path(image2))
    end
  end

  it "shows the top images' metadata" do
    render
    # NOTE: these don't work with "have content" because they are stored in data
    # attributes.
    expect(rendered).to match "Image license name"
    expect(rendered).to match "Owner 1"
    expect(rendered).to match "Owner 2"
    expect(rendered).to match "Awesome First Image"
    expect(rendered).to match "Great Second Image"
  end

  it "shows the ancestor names" do
    render
    expect(rendered).to match "Parent Canon"
    expect(rendered).to match "Ancestor Canon"
  end

  it "shows a media subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/media")
    expect(rendered).to have_content /2\s*Media/
  end

  it "shows a data subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/traits")
    expect(rendered).to have_content /3\s*Traits/
  end

  it "shows a details subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/details")
    expect(rendered).to have_content /1\s*Details/
  end

  it "shows a classification subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/classifications")
    expect(rendered).to have_content /1\s*Classification/
  end

  it "shows a names subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/names")
    expect(rendered).to have_content /2\s*Names/
  end

  it "shows a literature_and_references subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/literature_and_references")
    expect(rendered).to have_content /3\s*References/
  end

  context "Empty page" do
    let (:empty_page) do
      node = instance_double("Node", ancestors: [], name: "SomeTaxon", id: 1,
        children: [], resource: resource, has_breadcrumb?: true)
      sci_name = instance_double("ScientificName", node: node,
        italicized: "<i>Nice scientific</i>",
        taxonomic_status: TaxonomicStatus.synonym)
      instance_double("Page",
        id: 3497,
        articles: [],
        articles_count: 0,
        nodes_count: 0, # NOTE: this should actually be impossible, but JUST IN CASE...
        glossary: [],
        grouped_traits: nil,
        habitats: "",
        iucn_status_key: nil,
        is_it_extinct?: false,
        is_it_marine?: false,
        literature_and_references_count: 0,
        map?: false,
        media_count: 0,
        nodes: [node],
        name: sci_name.italicized,
        names_count: 0,
        native_node: nil,
        occurrence_map?: false,
        predicates: [],
        scientific_name: sci_name.italicized,
        scientific_names: [sci_name],
        top_image: nil,
        traits: [],
        traits_count: 0,
        vernaculars: [],
        richness: 0,
        page_contents_count: 0,
        links_count: 0,
        maps_count: 0,
        vernaculars_count: 0,
        scientific_names_count: 0,
        referents_count: 0,
        species_count: 0,
        updated_at: Time.now
      )
    end

    before do
      assign(:page, empty_page)
      render
    end

    it "does NOT show a media subtab" do
      render
      expect(rendered).not_to have_link(href: "/pages/#{page.id}/media")
    end

    it "does NOT show a data subtab" do
      render
      expect(rendered).not_to have_link(href: "/pages/#{page.id}/traits")
    end

    it "does NOT show a details subtab" do
      render
      expect(rendered).not_to have_link(href: "/pages/#{page.id}/details")
    end

    it "does NOT show a classification subtab" do
      render
      expect(rendered).not_to have_link(href: "/pages/#{page.id}/classifications")
    end

    it "does NOT show a names subtab" do
      render
      expect(rendered).not_to have_link(href: "/pages/#{page.id}/names")
    end

    it "does NOT show a literature_and_references subtab" do
      render
      expect(rendered).not_to have_link(href: "/pages/#{page.id}/literature_and_references")
    end
  end

  # TODO! Articles were moved to another (Ajaxy) view, so this won't work now.
  # it "shows the article" do
  #   render
  #   expect(rendered).to match /Article license name/
  #   expect(rendered).to match /Article Name/
  #   expect(rendered).to match /Article body/
  #   expect(rendered).to match /Article owner/
  # end
  #
  # it "shows the article section name if article name is missing" do
  #   expect(page).to receive(:article) { nil }
  #   render
  #   expect(rendered).not_to have_content(I18n.t(:page_article_header))
  # end

  # These only apply when traits tab is shown:
  # it "shows the predicates once each" do
  #   render
  #   # NOTE: have_content doesn't seem to work with traits: it creates
  #   # duplicates. Not sure why.
  #   expect(rendered).to match(/Predicate One/)
  #   expect(rendered).not_to match(/Predicate One.*Predicate One/)
  #   expect(rendered).to match(/Predicate Two/)
  #   expect(rendered).not_to match(/Predicate Two.*Predicate Two/)
  # end
  #
  # it "shows measurements and units" do
  #   render
  #   expect(rendered).to match /657\s+Units URI/
  # end
  #
  # it "shows terms" do
  #   render
  #   expect(rendered).to match /Term URI/
  # end
  #
  # it "shows literal trait values" do
  #   render
  #   expect(rendered).to match /literal trait value/
  # end
  #
  # it "shows resource names when available" do
  #   render
  #   expect(rendered).to match /Short Res Name/
  # end
end
