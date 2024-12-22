# frozen_string_literal: true
require "generators/devise_twilio_verify/devise_twilio_verify_generator"

RSpec.describe DeviseTwilioVerify::Generators::DeviseTwilioVerifyGenerator, type: :generator do
  destination File.expand_path("../../tmp", __FILE__)

  after(:all) do
    prepare_destination
  end

  def prepare_app
    FileUtils.mkdir_p(File.join(destination_root, "app", "models"))
    File.open(File.join(destination_root, "app", "models", "user.rb"), "w") do |file|
      file << "class User < ActiveRecord::Base\n" \
              "  devise :database_authenticatable, :registerable,\n" \
              "         :recoverable, :rememberable, :trackable, :validatable\n" \
              "  attr_accessible :email\n" \
              "end"
    end
  end

  before(:all) do
    prepare_destination
    prepare_app
    run_generator ["user"]
  end

  it "adds twilio_verify_authenticatable module and twilio_verify attributes" do
    expect(destination_root).to have_structure {
      directory "app" do
        directory "models" do
          file "user.rb" do
            contains "devise :twilio_verify_authenticatable"
            contains "attr_accessible :authy_id, :last_sign_in_with_twilio_verify, :email"
          end
        end
      end
    }
  end
end
