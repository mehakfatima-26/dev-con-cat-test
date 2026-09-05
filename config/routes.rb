Rails.application.routes.draw do
  devise_for :users
  root to: "dashboard#show"

  namespace :admin do
    root to: "dashboard#show"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
