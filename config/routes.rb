Rails.application.routes.draw do

  # Putting pages first only because it"s the most common:
  resources :pages, only: [:show]

  # Putting users second only because they tend to drive a lot of site behavior:
  devise_for :users, controllers: { registrations: "user/registrations",
                                    sessions: "user/sessions",
                                    omniauth_callbacks: "user/omniauth_callbacks"}
  resources :users do
    collection do
      post "delete_user", defaults: { format: "json" }
    end
  end

  # All of the "normal" resources:
  resources :collections do
    member do
      get "sort"
    end
  end
  resources :collection_associations, only: [:new, :create]
  resources :collected_pages, only: [:new, :create] do
    collection do
      get "search", defaults: { format: "json" }
      get "search_results"
    end
  end
  resources :media, only: [:show]
  resources :open_authentications, only: [:new, :create]
  resources :page_icons, only: [:create]

  get "/terms" => "terms#show", :as => "term"

  # Non-resource routes last:
  get "/search" => "search#search", :as => "search"
  get "/clade_filter" => "terms#clade_filter", :as => "clade_filter"

  # TODO: Change. We really want this to point to a (dynamic) CMS page of some
  # sort.
  root "users#index"
end
