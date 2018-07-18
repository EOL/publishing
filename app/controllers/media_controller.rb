class MediaController < ApplicationController
  layout "application"

  def show
    @medium = Medium.where(id: params[:id]).includes(
      :license,
      :bibliographic_citation,
      :location,
      page_contents: {
        page: [
          {
            native_node: :scientific_names
          },
          :preferred_vernaculars
        ]
      },
      attributions: :role
    ).first
    return render(status: :not_found) unless @medium 
  end
end
