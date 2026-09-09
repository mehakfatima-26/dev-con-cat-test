Rails.application.routes.draw do
  devise_for :users
  root to: "dashboard#show"

  resources :leads, only: %i[index show]
  resource :pixel, only: %i[show new create]

  get "verify/:serial", to: "certificates#show", as: :verify_certificate

  namespace :admin do
    root to: "dashboard#show"
  end

  namespace :api do
    namespace :pixel do
      post "visit", to: "capture_sessions#create"
      post "leads", to: "leads#create"
      get "leads/:lead_id/activity", to: "activities#show", as: :lead_activity
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
