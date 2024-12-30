appraise "rails-5-2" do
  gem "rails", "~> 5.2.0"
  gem "sqlite3", "~> 1.3.13"

  group :development, :test do
    gem 'factory_girl_rails', require: false
    gem 'rspec-rails', "~> 5.0.0", require: false
    gem 'database_cleaner', require: false
  end
end if RUBY_VERSION.to_f < 3.0

appraise "rails-6" do
  gem "rails", "~> 6.0.0"
  gem "sqlite3", "~> 1.4"
  gem "net-smtp"

  group :development, :test do
    gem 'factory_girl_rails', require: false
    gem 'rspec-rails', "~> 5.0.0", require: false
    gem 'database_cleaner', require: false
  end
end if RUBY_VERSION.to_f >= 2.5

appraise "rails-7" do
  gem "rails", "~> 7.0.8"
  gem "sqlite3", "~> 1.4"
  gem "net-smtp"

  group :development, :test do
    gem 'factory_girl_rails', require: false
    gem 'rspec-rails', "~> 7.0.0", require: false
    gem 'database_cleaner', require: false
  end
end if RUBY_VERSION.to_f >= 2.7

appraise "rails-7-1" do
  gem "rails", "~> 7.1.5"
  gem "sqlite3", "~> 1.4"
  gem "net-smtp"

  group :development, :test do
    gem 'factory_girl_rails', require: false
    gem 'rspec-rails', "~> 7.1.0", require: false
    gem 'database_cleaner', require: false
  end
end if RUBY_VERSION.to_f >= 2.7
