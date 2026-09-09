Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ->(source, _env) { Pixel.active.where("? = ANY(allowed_origins)", source).exists? }

    resource "/api/pixel/*",
      headers: :any,
      methods: %i[get post options],
      credentials: false
  end
end
