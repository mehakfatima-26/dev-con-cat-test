source "https://rubygems.org"

gem "rails", "~> 7.2.3", ">= 7.2.3.2"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "redis", "~> 5.0"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

gem "devise"
gem "pundit"
gem "sidekiq"
gem "rack-attack"
gem "rack-cors"

group :development, :test do
  gem "brakeman", require: false
  gem "byebug"
  gem "rubocop-rails-omakase", require: false
  gem "dotenv-rails"

  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  gem "web-console"
end
