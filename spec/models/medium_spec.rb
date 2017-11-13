require 'rails_helper'

RSpec.describe Medium do
  let(:types) { [ :image, :video, :sound, :map, :js_map ] }
  subject { Medium.new(base_url: "base") }

  it "#name can take a language argument" do
    expect(subject.name(Language.english)).to eq(subject.name)
  end

  it "builds a #original_size_url" do
    expect(subject.original_size_url).to eq(fake_img_path("base", :orig))
  end

  it "builds a #large_size_url" do
    expect(subject.large_size_url).to eq(fake_img_path("base", 580, 360))
  end

  it "builds a #medium_icon_url" do
    expect(subject.medium_icon_url).to eq(fake_img_path("base", 130, 130))
  end

  it "builds an #icon" do
    expect(subject.icon).to eq(fake_img_path("base", 130, 130))
  end

  it "builds a #medium_size_url" do
    expect(subject.medium_size_url).to eq(fake_img_path("base", 260, 190))
  end

  it "builds a #small_size_url" do
    expect(subject.small_size_url).to eq(fake_img_path("base", 98, 68))
  end

  it "builds a #small_icon_url" do
    expect(subject.small_icon_url).to eq(fake_img_path("base", 88, 88))
  end

  it "has is_type? booleans" do
    types.each do |type|
      subject.subclass = type
      types.map { |t| "is_#{t}?".to_sym }.each do |test_type|
        if test_type == type
          expect(subject.send(test_type)).to be_true
        else
          expect(subject.send(test_type)).to be_falsey
        end
      end
    end
  end
end
