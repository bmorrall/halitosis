Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  resources :simple_jsons, only: [:index, :show]
  resources :simple_renderables, only: [:index, :show]

  resources :complex_renderables, only: :show

  resources :includeable_examples, only: :show

  resources :sortable_articles, only: :index
  resources :filterable_articles, only: :index
  resources :paginatable_articles, only: :index
  resources :linkable_articles, only: :index

  resources :kaminari_articles, only: :index
  resources :will_paginate_articles, only: :index
  resources :pagy_articles, only: :index
  resources :pipeline_articles, only: :index

  resources :preloading_books, only: :show
  resources :preloading_libraries, only: :show

  # Defines the root path route ("/")
  # root "posts#index"
end
