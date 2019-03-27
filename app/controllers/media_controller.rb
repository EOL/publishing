class MediaController < ApplicationController
  layout "application"

  before_filter :get_medium

  def show
  end

  def fix_source_pages
    @medium.fix_source_pages
    flash[:notice] = '"Appears on" pages have been repaired. The list now reflects what is in the database.'
    render action: :show
  end

private

  def get_medium
    @medium = Medium.includes(
      :license,
      :bibliographic_citation,
      :location,
      page_contents: {
        page: [
          {
            native_node: [
              :scientific_names,
              {
                node_ancestors: {
                  ancestor: :page
                }
              }
            ]
          },
          :preferred_vernaculars
        ]
      },
      attributions: :role
    ).find(params[:id] || params[:medium_id])
  end
end
