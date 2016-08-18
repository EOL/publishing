Rails.application.routes.draw do

  # Putting pages first only because it"s the most common:
  resources :pages, only: [:show]

  devise_for :users, controllers: { registrations: "user/registrations",
                                    sessions: "user/sessions",
                                    omniauth_callbacks: "user/omniauth_callbacks"}

  resources :open_authentications, only: [:new, :create]

  resources :traits, only: [:show] # TODO: more coming later...

  get "/search" => "search#search", :as => "search"

  resources :users do
    collection do
      post "delete_user", defaults: { format: "json" }
    end
  end

  root "users#index"

  # Example of regular route:
  #   get "products/:id" => "catalog#view"

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get "products/:id/purchase" => "catalog#purchase", as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get "short"
  #       post "toggle"
  #     end
  #
  #     collection do
  #       get "sold"
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get "recent", on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post "toggle"
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
