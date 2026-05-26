Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  resources :simple_jsons, only: [:index, :show]
  resources :simple_renderables, only: [:index, :show]

  resource :validation_errors, only: :create
  post "validation_errors/json", to: "validation_errors#json_create", as: :json_validation_errors
  post "validation_errors/inferred", to: "validation_errors#inferred_create", as: :inferred_validation_errors

  resource :exception_error, only: :show
  get "exception_error/json", to: "exception_errors#json_show", as: :json_exception_error

  resources :complex_renderables, only: :show

  resources :includeable_examples, only: :show

  resources :sortable_articles, only: :index
  resources :filterable_articles, only: :index
  resources :typed_articles, only: :index
  resources :paginatable_articles, only: :index
  resources :linkable_articles, only: :index

  resources :kaminari_articles, only: :index
  resources :will_paginate_articles, only: :index
  resources :pagy_articles, only: :index
  resources :pipeline_articles, only: :index

  # Defines the root path route ("/")
  # root "posts#index"
end
