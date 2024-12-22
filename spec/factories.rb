# frozen_string_literal: true

FactoryBot.define do
  sequence :email do |n|
    "person#{n}@example.com"
  end

  sequence :authy_id do |n|
    n.to_s
  end

  factory :user do
    email { generate(:email) }
    password { "correct horse battery staple" }
    mobile_phone { '1234567890' }

    factory :twilio_verify_user do
      authy_id { generate(:authy_id) }
      twilio_verify_enabled { true }
    end
  end

  factory :lockable_user, class: LockableUser do
    email { generate(:email) }
    mobile_phone { '1234567890' }
    password { "correct horse battery staple" }
  end

  factory :lockable_twilio_verify_user, class: LockableUser do
    email { generate(:email) }
    mobile_phone { '1234567890' }
    password { "correct horse battery staple" }
    authy_id { generate(:authy_id) }
    twilio_verify_enabled { true }
  end
end
