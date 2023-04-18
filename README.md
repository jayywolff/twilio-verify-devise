# Migrate Authy to Twilio Verify API (for SMS and TOTP 2FA)

### This gem is meant to be a drop-in replacement for devise-authy in a Rails app (minus the following features)
- Removed Onetouch support
- Removed ability to request a phone call

### Just follow the steps below to migrate:
- Swap out `devise-authy` in your Gemfile with `devise-twilio-verify`
- `gem 'devise-twilio-verify'
- Setup a Twilio Verify account
- Add env vars and/or Rails credentials for:
  - `TWILIO_AUTH_TOKEN`
  - `TWILIO_ACCOUNT_SID`
  - `TWILIO_VERIFY_SERVICE_SID`
- Create/run a migration to rename  and add the following columns
  ```ruby
    class MigrateAuthyToTwilioVerify < ActiveRecord::Migration[6.1]
      def change
        rename_column :users, :authy_sms, :twilio_verify_sms
        rename_column :users, :authy_enabled, :twilio_verify_enabled
        rename_column :users, :last_sign_in_with_authy, :last_sign_in_with_twilio_verify
        add_column :users, :twilio_totp_factor_sid, :string
      end
    end

  ```
- you can also delete the `users.authy_id` column if you choose
- Twilio Verify service sms will be sent to `users.mobile_phone`, so make sure you store the users 2fa phone number in this column in [e164 format](https://www.twilio.com/docs/glossary/what-e164), can make this field name dynamic in the future
- Do a project code wide search & replace of these terms
  - `devise-authy` -> `devise-twilio-verify`
  - `authy_` -> `twilio_verify_`
  -  `_authy` -> `_twilio_verify`
  -  `authy-` -> `twilio-verify-`
  -  `-authy` -> `-twilio-verify`
  -  `Authy` -> `TwilioVerify`
- Do a project file search & replace of any file with authy in the name (here's a few examples to replace)
  - app/javascript/src/deviseTwilioVerify.js
  - app/assets/stylesheets/devise_twilio_verify.scss
  - config/locales/devise.twilio_verify.en.yml

# Twilio Verify Devise [![Build Status](https://github.com/twilio/authy-devise/workflows/build/badge.svg)](https://github.com/twilio/authy-devise/actions)

This is a [Devise](https://github.com/heartcombo/devise) extension to add [Two-Factor Authentication with Twilio Verify](https://www.twilio.com/docs/verify) to your Rails application.

Please visit the Twilio Docs for more information:
[Twilio Verify API](https://www.twilio.com/docs/verify)
* [Verify + Ruby (Rails) quickstart](https://www.twilio.com/docs/verify/quickstarts/ruby-rails)
* [Twilio Ruby helper library](https://www.twilio.com/docs/libraries/ruby)
* [Verify API reference](https://www.twilio.com/docs/verify/api)


* [Pre-requisites](#pre-requisites)
* [Demo](#demo)
* [Getting started](#getting-started)
  * [Configuring Models](#configuring-models)
    * [With the generator](#with-the-generator)
    * [Manually](#manually)
    * [Final steps](#final-steps)
* [Custom Views](#custom-views)
* [Custom Redirect Paths (eg. using modules)](#custom-redirect-paths-eg-using-modules)
* [I18n](#i18n)
* [Session variables](#session-variables)
* [Generic authenticator token support](#generic-authenticator-token-support)
* [Rails 5 CSRF protection](#rails-5-csrf-protection)
* [Running Tests](#running-tests)
* [Copyright](#copyright)

## Pre-requisites

To use the Twilio Verify API you will need a Twilio Account, [sign up for a free Twilio account here](https://www.twilio.com/try-twilio).

Create an [Twilio Verify Application in the Twilio console](https://www.twilio.com/console/authy/applications) and take note of the API key.

## Getting started

First get your Twilio Verify API key from [the Twilio console](https://www.twilio.com/console/authy/applications). We recommend you store your API key as an environment variable.

```bash
$ export TWILIO_AUTH_TOKEN=YOUR_TWILIO_AUTH_TOKEN
$ export TWILIO_ACCOUNT_SID=YOUR_TWILIO_ACCOUNT_SID
$ export TWILIO_VERIFY_SERVICE_SID=YOUR_TWILIO_VERIFY_SERVICE_SID
```

Next add the gem to your Gemfile:

```ruby
gem 'devise'
gem 'devise-twilio-verify'
```

And then run `bundle install`

Add `Devise Twilio Verify` to your App:

    rails g devise_twilio_verify:install

    --haml: Generate the views in Haml
    --sass: Generate the stylesheets in Sass

### Configuring Models

You can add devise_twilio_verify to your user model in two ways.

#### With the generator

Run the following command:

```bash
rails g devise_twilio_verify [MODEL_NAME]
```

To support account locking (recommended), you must add `:twilio_verify_lockable` to the `devise :twilio_verify_authenticatable, ...` configuration in your model as this is not yet supported by the generator.

#### Manually

Add `:twilio_verify_authenticatable` and `:twilio_verify_lockable` to the `devise` options in your Devise user model:

```ruby
devise :twilio_verify_authenticatable, :twilio_verify_lockable, :database_authenticatable, :lockable
```

(Note, `:twilio_verify_lockable` is optional but recommended. It should be used with Devise's own `:lockable` module).

Also add a new migration. For example, if you are adding to the `User` model, use this migration:

```ruby
class DeviseTwilioVerifyAddToUsers < ActiveRecord::Migration[6.0]
  def self.up
    change_table :users do |t|
      t.string    :authy_id
      t.datetime  :last_sign_in_with_twilio_verify
      t.boolean   :twilio_verify_enabled, :default => false
    end

    add_index :users, :authy_id
  end

  def self.down
    change_table :users do |t|
      t.remove :authy_id, :last_sign_in_with_twilio_verify, :twilio_verify_enabled
    end
  end
end
```

#### Final steps

For either method above, run the migrations:

```bash
rake db:migrate
```

**[Optional]** Update the default routes to point to something like:

```ruby
devise_for :users, :path_names => {
	:verify_twilio_verify => "/verify-token",
	:enable_twilio_verify => "/enable-two-factor",
	:verify_twilio_verify_installation => "/verify-installation"
}
```

Now whenever a user wants to enable two-factor authentication they can go to:

    http://your-app/users/enable-two-factor

And when the user logs in they will be redirected to:

    http://your-app/users/verify-token

## Custom Views

If you want to customise your views, you can modify the files that are located at:

    app/views/devise/devise_twilio_verify/enable_twilio_verify.html.erb
    app/views/devise/devise_twilio_verify/verify_twilio_verify.html.erb
    app/views/devise/devise_twilio_verify/verify_twilio_verify_installation.html.erb

## Custom Redirect Paths (eg. using modules)

If you want to customise the redirects you can override them within your own controller like this:

```ruby
class MyCustomModule::DeviseTwilioVerifyController < Devise::DeviseTwilioVerifyController

  protected
    def after_twilio_verify_enabled_path_for(resource)
      my_own_path
    end

    def after_twilio_verify_verified_path_for(resource)
      my_own_path
    end

    def after_twilio_verify_disabled_path_for(resource)
      my_own_path
    end

    def invalid_resource_path
      my_own_path
    end
end
```

And tell the router to use this controller

```ruby
devise_for :users, controllers: {devise_twilio_verify: 'my_custom_module/devise_twilio_verify'}
```

## I18n

The install generator also copies a `Devise Twilio Verify` i18n file which you can find at:

    config/locales/devise.twilio_verify.en.yml

## Session variables

If you want to know if the user is signed in using Two-Factor authentication,
you can use the following session variable:

```ruby
session["#{resource_name}_twilio_verify_token_checked"]

# Eg.
session["user_twilio_verify_token_checked"]
```

## Generic authenticator token support

Twilio Verify supports other authenticator apps by providing a QR code that your users can scan.

> **To use this feature, you need to enable it in your [Twilio Console](https://www.twilio.com/console/authy/applications)**

Once you have enabled generic authenticator tokens, you can enable this in devise-twilio-verify by modifying the Devise config file `config/initializers/devise.rb` and adding the configuration:

```
config.twilio_verify_enable_qr_code = true
```

This will display a QR code on the verification screen (you still need to take a user's phone number and country code). If you have implemented your own views, the QR code URL is available on the verification page as `@twilio_verify_qr_code`.

## Rails 5 CSRF protection

In Rails 5 `protect_from_forgery` is no longer prepended to the `before_action` chain. If you call `authenticate_user` before `protect_from_forgery` your request will result in a "Can't verify CSRF token authenticity" error.

To remedy this, add `prepend: true` to your `protect_from_forgery` call, like in this example from the [Twilio Verify Devise demo app](https://github.com/twilio/authy-devise-demo):

```ruby
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true
end
```

## Running Tests

Run the following command:

```bash
$ bundle exec rspec
```

## Copyright
See LICENSE.txt for further details.
