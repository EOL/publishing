require 'rails_helper'

RSpec.describe Medium do
  subject { Medium.new(base_url: "base") }

  it "#name can take a language argument" do
    expect(subject.name(Language.english)).to eq(subject.name)
  end

  it "builds a #original_size_url" do
    expect(subject.original_size_url).to eq("base_original.jpg")
  end

  it "builds a #large_size_url" do
    expect(subject.large_size_url).to eq("base_580_360.jpg")
  end

  it "builds a #medium_icon_url" do
    expect(subject.medium_icon_url).to eq("base_130_130.jpg")
  end

  it "builds an #icon" do
    expect(subject.icon).to eq("base_130_130.jpg")
  end

  it "builds a #medium_size_url" do
    expect(subject.medium_size_url).to eq("base_260_190.jpg")
  end

  it "builds a #small_size_url" do
    expect(subject.small_size_url).to eq("base_98_68.jpg")
  end

  it "builds a #small_icon_url" do
    expect(subject.small_icon_url).to eq("base_88_88.jpg")
  end
end
