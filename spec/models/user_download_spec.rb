require 'rails_helper'

RSpec.describe UserDownload, type: :model do
  it { should belong_to(:user) }
  it { should belong_to(:term_query).dependent(:delete) }
  it { should have_one(:download_error).dependent(:destroy) }


  describe "#before_destroy" do
    describe "when its status is complete" do
      let(:filename) { "filename.zip" }
      let(:full_path) { "/path/to/filename.zip" }
      let(:path) { instance_double("Pathname") }
      let!(:user_download) { create(:user_download, status: :completed, filename: filename) }
      let!(:data_download) { class_double("TraitBank::DataDownload").as_stubbed_const }
      let!(:file) { class_double("File").as_stubbed_const }


      it "deletes its file" do
        expect(data_download).to receive(:path).and_return(path)
        expect(path).to receive(:join).with(filename).and_return(full_path)
        expect(file).to receive(:delete).with(full_path)
        user_download.destroy
      end
    end
  end
end
