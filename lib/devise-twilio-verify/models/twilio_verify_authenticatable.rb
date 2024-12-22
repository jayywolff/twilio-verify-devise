require 'devise-twilio-verify/hooks/twilio_verify_authenticatable'
module Devise
  module Models
    module TwilioVerifyAuthenticatable
      extend ActiveSupport::Concern

      def with_twilio_verify_authentication?(request)
        self.twilio_verify_enabled?
      end

      module ClassMethods
        def find_by_mobile_phone(mobile_phone)
          return if mobile_phone.blank?

          where(mobile_phone: mobile_phone).first
        end

        Devise::Models.config(self, :twilio_verify_remember_device, :twilio_verify_enable_qr_code)
      end
    end
  end
end

