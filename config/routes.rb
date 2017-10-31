Rails.application.routes.draw do
  # Putting pages first only because it"s the most common:
  # TODO: move all the silly extra things to their own resources (I think).
  resources :pages, only: [:index, :show] do
    get "autocomplete", on: :collection
    get "topics", on: :collection
    get "breadcrumbs"
    get "comments"
    get "create_topic"
    get "overview"
    get "classifications"
    # NOTE this is a Rails collecton (as opposed to member), *not* an EOL
    # collection:
    get "clear_index_stats", on: :collection
    get "details"
    get "literature_and_references"
    get "maps"
    get "media"
    get "names"
    get "reindex"
    get "data"
  end

  resources :data, only: [:show]

  # Putting users second only because they tend to drive a lot of site behavior:
  devise_for :users, controllers: { registrations: "user/registrations",
                                    sessions: "user/sessions",
                                    omniauth_callbacks: "user/omniauth_callbacks"}
  resources :users do
    collection do
      get "autocomplete"
      post "delete_user", defaults: { format: "json" }
      get "search"
    end
    resources :user_downloads, only: [:show]
  end

  # All of the "normal" resources:
  resources :articles, only: [:show]
  resources :collections do
    get "logs"
    resources :collected_pages, only: [:index]
    # TODO: this is not very restful; should be a nested resource, but the terms
    # become somewhat tricky, so cheating for now. These aren't really
    # "public-facing URLs" anyway, so less concerned about it.
    post "add_user"
    post "remove_user"
  end
  resources :collection_associations, only: [:new, :create, :destroy]
  resources :collected_pages
  resources :media, only: [:show]
  resources :open_authentications, only: [:new, :create]
  resources :page_icons, only: [:create]
  resources :resources, only: [:index, :show] do
    resources :import_logs, only: [:show]
  end
  resources :search_suggestions

  # This isn't really a model, so we'll go oldschool:
  get "/terms/predicate_glossary" => "terms#predicate_glossary", :as => "predicate_glossary"
  get "/terms/object_term_glossary" => "terms#object_term_glossary", :as => "object_term_glossary"
  get "/terms/units_glossary" => "terms#units_glossary", :as => "units_glossary"
  get "/terms/new" => "terms#new", :as => "new_term"
  get "/terms/:uri" => "terms#show", :as => "term", :constraints => { uri: /http.*/ }
  post "/terms/:uri" => "terms#update", :as => "update_term", :constraints => { uri: /http.*/ }
  get "/terms/edit/:uri" => "terms#edit", :as => "edit_term", :constraints => { uri: /http.*/ }
  get "/terms" => "terms#index", :as => "terms"

  post "/collected_pages_media" => "collected_pages_media#destroy", :as => "destroy_collected_pages_medium"

  # Non-resource routes last:
  get "/search" => "search#search", :as => "search"
  get "/vernaculars/prefer/:id" => "vernaculars#prefer", :as => "prefer_vernacular"

  root "pages#index"

  # This line mounts Refinery's routes at the root of your application.
  # This means, any requests to the root URL of your application will go to Refinery::PagesController#home.
  # If you would like to change where this extension is mounted, simply change the
  # configuration option `mounted_path` to something different in config/initializers/refinery/core.rb
  #
  # We ask that you don't use the :as option here, as Refinery relies on it being the default of "refinery"
  #keep this at the end of the routes (Refinery smetimes can override other routes)
  mount Refinery::Core::Engine, at: Refinery::Core.mounted_path
end
