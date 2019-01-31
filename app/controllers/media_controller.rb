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
end
