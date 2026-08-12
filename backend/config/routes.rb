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

      # Singular: always the current user's session, no id in the URL, so another
      # user's record cannot be named let alone reached.
      get "onboarding_session", to: "onboarding_sessions#show_current"
      patch "onboarding_session", to: "onboarding_sessions#update_current"

      # Id-addressed and policy-guarded. Ownership is enforced explicitly here rather
      # than only implied by the routes above.
      resources :onboarding_sessions, only: :show

      # Consent. Singular: a user has one consent record, and granting, checking, and
      # withdrawing are the three things you can do to it.
      resource :consent, only: %i[show create destroy]

      # The uploaded ID. Singular, and consent-gated on create.
      resource :document, only: %i[show create]

      # Scheduling. The booking is singular for the same reason the session is:
      # a user has at most one, and no id in the URL means no other user's to name.
      resources :appointment_slots, only: :index
      resource :booking, only: %i[show create]
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
