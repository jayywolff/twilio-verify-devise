# frozen_string_literal: true

RSpec.describe TwilioVerifyService, type: :service do
  let(:user) { create :twilio_verify_user }
  let(:phone_number) { user.mobile_phone }
  let(:formatted_phone_number) { "+1#{phone_number}" }
  let(:twilio_account_sid) { '123456789' }
  let(:twilio_auth_token) { '123456789' }
  let(:twilio_verify_service_sid) { '123456789' }

  before do
    allow(Rails.application.credentials).to receive(:twilio_account_sid).and_return twilio_account_sid
    allow(Rails.application.credentials).to receive(:twilio_auth_token).and_return twilio_auth_token
    allow(Rails.application.credentials).to receive(:twilio_verify_service_sid).and_return twilio_verify_service_sid
  end

  describe 'Missing Twilio credentials' do
    let(:twilio_auth_token) { '' }

    it "raises 'Missing Twilio credentials' exception if any credentials are missing" do
      expect { described_class.new }.to raise_error 'Missing Twilio credentials'
    end
  end

  # https://www.twilio.com/docs/verify/sms
  describe 'SMS 2FA' do
    let(:twilio_client) { Twilio::REST::Client.new(twilio_account_sid, twilio_auth_token) }
    let(:twilio_client_verify_service) { double('Twilio::REST::Verify::V2::ServiceContext') }

    before do
      allow(Twilio::REST::Client).to receive(:new).with(twilio_account_sid, twilio_auth_token).and_return twilio_client
      allow(twilio_client).to receive_message_chain(:verify, :services).with(twilio_verify_service_sid).and_return twilio_client_verify_service
    end

    describe '.send_sms_token' do
      it 'calls on the Twilio Verify API to send a one-time code to the given phone number via SMS' do
        expect(twilio_client_verify_service).to receive_message_chain(:verifications, :create).with(to: formatted_phone_number, channel: 'sms')
        described_class.send_sms_token(phone_number)
      end
    end

    describe '.verify_sms_token' do
      let(:token) { '123456' }

      it 'calls on the Twilio Verify API to verify a one-time code that was previously sent to the given phone number via SMS' do
        expect(twilio_client_verify_service).to receive_message_chain(:verification_checks, :create).with(to: formatted_phone_number, code: token)
        described_class.verify_sms_token(phone_number, token)
      end
    end
  end

  # https://www.twilio.com/docs/verify/quickstarts/totp
  describe 'TOTP 2FA' do
    let(:twilio_client) { Twilio::REST::Client.new(twilio_account_sid, twilio_auth_token) }
    let(:twilio_client_verify_service) { double('Twilio::REST::Verify::V2::ServiceContext') }
    let(:twilio_client_entity) { double('Twilio::REST::Verify::V2::ServiceContext::EntityContext') }

    before do
      allow(Twilio::REST::Client).to receive(:new).with(twilio_account_sid, twilio_auth_token).and_return twilio_client
      allow(twilio_client).to receive_message_chain(:verify, :v2, :services).with(twilio_verify_service_sid).and_return twilio_client_verify_service
      allow(twilio_client_verify_service).to receive(:entities).with("test-#{user.id}").and_return twilio_client_entity
    end

    describe '.setup_totp_service' do
      it 'calls on the Twilio Verify API to setup TOTP for a given user' do
        new_factor = double(:twilio_verify_totp_new_factor, sid: '123ABC')
        expect(twilio_client_entity).to receive_message_chain(:new_factors, :create).with(friendly_name: user.to_s, factor_type: 'totp').and_return new_factor

        expect(user.twilio_totp_factor_sid).to be_nil
        result = described_class.setup_totp_service(user)

        expect(user.reload.twilio_totp_factor_sid).to eq result.sid
      end
    end

    describe '.register_totp_service' do
      let(:token) { '123456' }
      let(:new_factor) { double(:twilio_verify_totp_new_factor, status: 'verified') }

      before do
        user.update!(twilio_totp_factor_sid: '123ABC')
        allow(twilio_client_entity).to receive(:factors).with(user.twilio_totp_factor_sid).and_return new_factor
      end

      it 'calls on the Twilio Verify API to register TOTP for a given user' do
        expect(new_factor).to receive(:update).with(auth_payload: token).and_return new_factor

        result = described_class.register_totp_service(user, token)
        expect(result.status).to eq 'verified'
      end

      context 'when an invalid token is provided' do
        let(:new_factor) { double(:twilio_verify_totp_new_factor, status: 'unverified') }

        it 'returns an unverified status' do
          expect(new_factor).to receive(:update).with(auth_payload: token).and_return new_factor

          result = described_class.register_totp_service(user, token)
          expect(result.status).to eq 'unverified'
        end
      end
    end

    describe '.verify_totp_token' do
      let(:token) { '123456' }

      before { user.update!(twilio_totp_factor_sid: '123ABC') }

      it 'calls on the Twilio Verify API to verify a TOTP based one time code for a given user' do
        expect(twilio_client_entity).to receive_message_chain(:challenges, :create).with(auth_payload: token, factor_sid: user.twilio_totp_factor_sid)
        described_class.verify_totp_token(user, token)
      end
    end
  end

  describe '.e164_format' do
    # https://en.wikipedia.org/wiki/E.164
    it 'formats supplied phone number to the e164 format' do
      expect(described_class.e164_format(phone_number)).to eq formatted_phone_number
      expect(described_class.e164_format('(123) 456-7890')).to eq '+11234567890'
      expect(described_class.e164_format('123-456-7890')).to eq '+11234567890'
      expect(described_class.e164_format('1234567890')).to eq '+11234567890'
    end
  end
end
