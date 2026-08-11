Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Rails' built-in liveness check: 200 if the app boots without raising. Kept because
  # Railway's default healthcheck path expects it, but it says nothing about whether
  # dependencies are reachable — use /api/v1/health for that.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Dependency-aware health report. Unauthenticated and safe to poll every minute.
      get "health", to: "health#show"

      # The authenticated user's own record.
      get "me", to: "me#show"
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
