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
      name: "Awesome First Image", resource: resource)
  end
  let(:image2) do
    instance_double("Medium", license: lic2, owner: "&copy; Owner 2", id: 2,
      small_icon_url: "no_matter", original_size_url: "img2_full_size.jpg",
      large_size_url: "second_url_580_360.jpg", medium_size_url: "img2_med.jpg",
      name: "Great Second Image", resource: resource)
  end
  let(:rank) { create(:rank) }
  let(:rank_sp) { create(:rank, name: "species") }

  # NOTE: I think we'll eventually want to extract this into a nice class to
  # mock pages for views... but ATM we only need it once, here, so I'm leaving
  # it despite its gross size and complexity:
  let(:page) do
    double_page(rank: rank, resource: resource, media: [image1, image2])
  end

  before do
    assign(:page, page)
    media = [image1, image2]
    allow(media).to receive(:total_pages) { 1 } # kaminari
    allow(media).to receive(:current_page) { 1 } # kaminari
    allow(media).to receive(:limit_value) { 2 } # kaminari
    user = instance_double("User", collections: [], is_admin?: false)
    allow(view).to receive(:current_user) { user }
    assign(:media, media)
    assign(:resources, { resource.id => resource })
    allow(view).to receive(:is_admin?) { false }
  end

#TODO: move these to a media spec
  # context "with the media subtab showing" do
  #
  #   before { render }
  #
  #   it "shows the image names" do
  #     expect(rendered).to match image1.name
  #     expect(rendered).to match image2.name
  #   end
  #
  #   it "shows the image medium icon" do
  #     # NOTE: I had a much fancier #have_tag implementation here, but it was
  #     # failing with "expected [HTML] to respond to `has_tag?`" ...and I
  #     # couldn't fix it. Easier to just move on right now. This will do.
  #     expect(rendered).to match image1.medium_size_url
  #     expect(rendered).to match image2.medium_size_url
  #   end
  #
  #   it "shows the image original size (modal)" do
  #     expect(rendered).to match image1.original_size_url
  #     expect(rendered).to match image2.original_size_url
  #   end
  #
  #   # NOTE: implementation as of this writing:
  #   # image.owner.html_safe.sub(/^\(c\)\s+/i, "").sub(/^&copy;\s+/i, "")
  #   it "shows the image owner" do
  #     expect(rendered).to match "Owner 1"
  #     expect(rendered).to match "Owner 2"
  #   end
  #
  #   # Note: this is a weak test. Each
  #   it "shows the license name" do
  #     expect(rendered).to match lic1.name
  #     expect(rendered).to match lic2.name
  #   end
  #
  #   it "shows the trust state" # TODO (we haven't implemented this yet)
  #
  #   it "has a link to make exemplar (but NOT the first image!)" do
  #     expect(rendered).not_to have_link(href: page_icons_path(page_id: page.id, medium_id: image1.id))
  #     expect(rendered).to have_link(href: page_icons_path(page_id: page.id, medium_id: image2.id))
  #   end
  #
  #   it "has a link to add to collection" do
  #     expect(rendered).to have_link(href: new_collected_page_path(page_id: page.id, medium_ids: [image1.id]))
  #     expect(rendered).to have_link(href: new_collected_page_path(page_id: page.id, medium_ids: [image2.id]))
  #   end
  #
  #   it "has a link to the image page" do
  #     expect(rendered).to have_link(href: medium_path(image1))
  #     expect(rendered).to have_link(href: medium_path(image2))
  #   end
  # end
  #
  # it "shows the top images' metadata" do
  #   render
  #   # NOTE: these don't work with "have content" because they are stored in data
  #   # attributes.
  #   expect(rendered).to match "Image license name"
  #   expect(rendered).to match "Owner 1"
  #   expect(rendered).to match "Owner 2"
  #   expect(rendered).to match "Awesome First Image"
  #   expect(rendered).to match "Great Second Image"
  # end


  context "Empty page" do
    let (:empty_page) do
      double_empty_page(rank: rank_sp, resource: resource)
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
      expect(rendered).not_to have_link(href: "/pages/#{page.id}/data")
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

  # These only apply when data tab is shown:
  # it "shows the predicates once each" do
  #   render
  #   # NOTE: have_content doesn't seem to work with data: it creates
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
  # it "shows literal data values" do
  #   render
  #   expect(rendered).to match /literal data value/
  # end
  #
  # it "shows resource names when available" do
  #   render
  #   expect(rendered).to match /Short Res Name/
  # end
end
