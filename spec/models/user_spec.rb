# frozen_string_literal: true

RSpec.describe User, type: :model do
  describe "with a user with a mobile phone" do
    let!(:user) { create(:twilio_verify_user) }

    describe "User#find_by_mobile_phone" do
      it "should find the user" do
        expect(User.first).not_to be nil
        expect(User.find_by_mobile_phone(user.mobile_phone)).to eq(user)
      end

      it "shouldn't find the user with the wrong id" do
        expect(User.find_by_mobile_phone('21')).to be nil
      end
    end

    describe "user#with_twilio_verify_authentication?" do
      it "should be false when twilio verify isn't enabled" do
        user.twilio_verify_enabled = false
        request = double("request")
        expect(user.with_twilio_verify_authentication?(request)).to be false
      end

      it "should be true when twilio verify is enabled" do
        user.twilio_verify_enabled = true
        request = double("request")
        expect(user.with_twilio_verify_authentication?(request)).to be true
      end
    end

  end

  describe "with a user without a mobile phone" do
    describe "User#find_by_mobile_phone" do
      let!(:user) { create :user, mobile_phone: nil }

      it "should not find the user" do
        expect(User.first).not_to be nil
        expect(User.find_by_mobile_phone(user.mobile_phone)).to be_nil
      end

      it "shouldn't find the user with the wrong id" do
        expect(User.find_by_mobile_phone('21')).to be_nil
      end
    end

    describe "user#with_twilio_verify_authentication?" do
      let(:request) { double :request }

      context 'when user has twilio verify enabled' do
        let(:user) { create :user, twilio_verify_enabled: true }

        it 'returns true' do
          expect(user.with_twilio_verify_authentication?(request)).to be true
        end
      end

      context 'when user does not have twilio verify enabled' do
        let(:user) { create :user, twilio_verify_enabled: false }

        it 'returns false' do
          expect(user.with_twilio_verify_authentication?(request)).to be false
        end
      end
    end
  end
end
