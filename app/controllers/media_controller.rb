class MediaController < ApplicationController
  layout "application"

  def show
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
    ).find(params[:id])
  end

  def fix_source_pages
    @medium = Medium.find(params[:id])
    flash[:notice] = '"Appears on" pages have been repaired. The list now reflects what is in the database.'
    redirect_to(medium_path(@medium))
  end
end
