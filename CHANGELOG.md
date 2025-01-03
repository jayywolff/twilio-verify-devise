# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.2.5] - 2025-01-02

### Changed

- Raise "Missing Twilio Credentials" when Twilio credentials are nil or empty strings.
- Added test coverage for TwilioVerifyService, (the abstraction layer for Twilio Verify API calls)
- Updated gemspec summary/description again

## [0.2.4] - 2024-12-29

### Changed

- Updated gemspec description for better SEO

## [0.2.3] - 2024-12-29

### Changed

- Updated gemspec description 

## [0.2.2] - 2024-12-29

### Changed

- Updated gemspec summary/description 

## [0.2.1] - 2024-12-29

### Changed

- Added apprasials for testing against Rails 7 and Rails 7.1
- Bump rspec-rails version from "~>4.0.0.beta3" to "~> 5.0.0" for Rails 5.2 and Rails 6 testing
- Updated README to move the authy migration instructions a bit below the README gem introduction / instructions

## [0.2.0] - 2024-12-21

### Changed

- Bugfix to not return any users when the mobile phone number is missing when querying for a user with `User.find_by_mobile_phone`
- Fixed test coverage from the initial fork from Authy to Twilio Verify API
- Disabled specs for TOTP setup. Currently there's just a method exposed to generate a code with the Twilio Verify service. Rails apps consuming the gem are expected to to generate a qr code with this code and present it to the user to scan. This feature can be added in the future
- Restored original flash message behavior from authy-devise on a few endpoints. Despite this being the original behavior, due to this change I will bump versioning as minor version release for Rails apps that did not migrate from devise-authy

## [0.1.1] - 2023-04-12

### Changed

- Updated README to point to published rubygem

## [0.1.0] - 2023-03-15 Initial release

### Changed

- Added devise 2FA support via Twilio Verify API
- Currently only support mobile phones with US country codes
- Removed Authy support
- Removed Onetouch support
- Removed ability to request a phone call
