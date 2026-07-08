Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "dashboard" => "dashboard#index", as: :dashboard

  resource :onboarding, only: %i[show create], controller: "onboarding" do
    post :skip
  end

  resources :relationship_profiles do
    patch :archive, on: :member
    resources :important_dates, except: %i[index show]
    resources :gifts, except: %i[index show] do
      patch :mark_given, on: :member
    end
    resources :memory_records, except: %i[index show] do
      patch :review, on: :member
      patch :approve_high_impact_automation, on: :member
    end
    resources :desires, except: %i[index show] do
      patch :fulfill, on: :member
    end
  end

  namespace :admin do
    resources :feature_flags, only: :index
  end

  root "welcome#index"
end
