# Cross-origin access for the Next.js frontend, which is deployed to a different
# origin (Vercel) than this API (Railway).
#
# Inserted at position 0 so preflight OPTIONS requests are answered before any other
# middleware can swallow them.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGINS", "http://localhost:3000").split(",").map(&:strip))

    resource "*",
      headers: :any,
      methods: %i[get post patch put delete options head],
      # Bearer tokens, never cookies. Nothing is sent ambiently, so there is no CSRF
      # surface and no exposure to third-party-cookie blocking between the Vercel and
      # Railway origins. Do not flip this to true.
      credentials: false,
      # Every cross-origin request carrying an Authorization header triggers a
      # preflight. Caching it for a day removes a full round trip from the p95.
      max_age: 86_400
  end
end
