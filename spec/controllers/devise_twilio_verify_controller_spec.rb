# frozen_string_literal: true

RSpec.describe Devise::DeviseTwilioVerifyController, type: :controller do
  let(:user) { create(:twilio_verify_user) }
  before(:each) { request.env["devise.mapping"] = Devise.mappings[:user] }

  describe "first step of authentication not complete" do
    describe "with no user details in the session" do
      describe "#GET_verify_twilio_verify" do
        it "should redirect to the root_path" do
          get :GET_verify_twilio_verify
          expect(response).to redirect_to(root_path)
        end
      end

      describe "#POST_verify_twilio_verify" do
        it "should redirect to the root_path" do
          post :POST_verify_twilio_verify
          expect(response).to redirect_to(root_path)
        end

        it "should not verify a token" do
          expect(TwilioVerifyService).not_to receive(:verify_sms_token)
          post :POST_verify_twilio_verify
        end
      end
    end

    describe "without checking the password" do
      before(:each) { request.session["user_id"] = user.id }

      describe "#GET_verify_twilio_verify" do
        it "should redirect to the root_path" do
          get :GET_verify_twilio_verify
          expect(response).to redirect_to(root_path)
        end
      end

      describe "#POST_verify_twilio_verify" do
        it "should redirect to the root_path" do
          post :POST_verify_twilio_verify
          expect(response).to redirect_to(root_path)
        end

        it "should not verify a token" do
          expect(TwilioVerifyService).not_to receive(:verify_sms_token)
          post :POST_verify_twilio_verify
        end
      end
    end
  end

  describe "when the first step of authentication is complete" do
    before do
      request.session["user_id"] = user.id
      request.session["user_password_checked"] = true
    end

    describe "GET #verify_twilio_verify" do
      it "Should render the second step of authentication" do
        get :GET_verify_twilio_verify
        expect(response).to render_template('verify_twilio_verify')
      end
    end

    describe "POST #verify_twilio_verify" do
      let(:verify_success) { double("Twilio::Verify::Response", status: 'approved') }
      let(:verify_failure) { double("Twilio::Verify::Response", status: 'failed') }
      let(:valid_twilio_verify_token) { rand(0..999999).to_s.rjust(6, '0') }
      let(:invalid_twilio_verify_token) { rand(0..999999).to_s.rjust(6, '0') }

      describe "with a valid token" do
        before(:each) {
          expect(TwilioVerifyService).to receive(:verify_sms_token).with(user.mobile_phone, valid_twilio_verify_token).and_return(verify_success)
        }

        describe "without remembering" do
          before(:each) {
            post :POST_verify_twilio_verify, params: { :token => valid_twilio_verify_token }
          }

          it "should log the user in" do
            expect(subject.current_user).to eq(user)
            expect(session["user_twilio_verify_token_checked"]).to be true
          end

          it "should set the last_sign_in_with_twilio_verify field on the user" do
            expect(user.last_sign_in_with_twilio_verify).to be_nil
            user.reload
            expect(user.last_sign_in_with_twilio_verify).not_to be_nil
            expect(user.last_sign_in_with_twilio_verify).to be_within(1).of(Time.zone.now)
          end

          it "should redirect to the root_path and set a flash notice" do
            expect(response).to redirect_to(root_path)
            expect(flash[:notice]).not_to be_nil
            expect(flash[:error]).to be nil
          end

          it "should not set a remember_device cookie" do
            expect(cookies["remember_device"]).to be_nil
          end

          it "should not remember the user" do
            user.reload
            expect(user.remember_created_at).to be nil
          end
        end

        describe "and remember device selected" do
          before(:each) {
            post :POST_verify_twilio_verify, params: {
              :token => valid_twilio_verify_token,
              :remember_device => '1'
            }
          }

          it "should set a signed remember_device cookie" do
            jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
            cookie = jar.signed["remember_device"]
            expect(cookie).not_to be_nil
            parsed_cookie = JSON.parse(cookie)
            expect(parsed_cookie["id"]).to eq(user.id)
          end
        end

        describe "and remember_me in the session" do
          before(:each) do
            request.session["user_remember_me"] = true
            post :POST_verify_twilio_verify, params: { :token => valid_twilio_verify_token }
          end

          it "should remember the user" do
            user.reload
            expect(user.remember_created_at).to be_within(1).of(Time.zone.now)
          end
        end
      end

      describe "with an invalid token" do
        before(:each) do
          expect(TwilioVerifyService).to receive(:verify_sms_token).with(user.mobile_phone, invalid_twilio_verify_token).and_return(verify_failure)
          post :POST_verify_twilio_verify, params: { :token => invalid_twilio_verify_token }
        end

        it "Shouldn't log the user in" do
          expect(subject.current_user).to be nil
        end

        it "should redirect to the verification page" do
          expect(response).to render_template('verify_twilio_verify')
        end

        it "should set an error message in the flash" do
          expect(flash[:notice]).to be nil
          expect(flash[:error]).not_to be nil
        end
      end

      describe 'with a lockable user' do
        let(:lockable_user) { create(:lockable_twilio_verify_user) }
        before(:all) { Devise.lock_strategy = :failed_attempts }

        before(:each) do
          request.session["user_id"] = lockable_user.id
          request.session["user_password_checked"] = true
        end

        it 'locks the account when failed_attempts exceeds maximum' do
          expect(TwilioVerifyService).to receive(:verify_sms_token).exactly(Devise.maximum_attempts).times.with(
            lockable_user.mobile_phone,
            invalid_twilio_verify_token,
          ).and_return(verify_failure)

          Devise.maximum_attempts.times do
            post :POST_verify_twilio_verify, params: { token: invalid_twilio_verify_token }
          end

          lockable_user.reload
          expect(lockable_user.access_locked?).to be true
        end
      end

      describe 'with a user that is not lockable' do
        it 'does not lock the account when failed_attempts exceeds maximum' do
          request.session['user_id']               = user.id
          request.session['user_password_checked'] = true

          expect(TwilioVerifyService).to receive(:verify_sms_token).exactly(Devise.maximum_attempts).times.with(
            user.mobile_phone,
            invalid_twilio_verify_token,
          ).and_return(verify_failure)

          Devise.maximum_attempts.times do
            post :POST_verify_twilio_verify, params: { token: invalid_twilio_verify_token }
          end

          user.reload
          expect(user.locked_at).to be_nil
        end
      end
    end
  end

  describe 'enabling/disabling twilio verify' do
    describe "with no-one logged in" do
      it "GET #enable_twilio_verify should redirect to sign in" do
        get :GET_enable_twilio_verify
        expect(response).to redirect_to(new_user_session_path)
      end

      it "POST #enable_twilio_verify should redirect to sign in" do
        post :POST_enable_twilio_verify
        expect(response).to redirect_to(new_user_session_path)
      end

      it "GET #verify_twilio_verify_installation should redirect to sign in" do
        get :GET_verify_twilio_verify_installation
        expect(response).to redirect_to(new_user_session_path)
      end

      it "POST #verify_twilio_verify_installation should redirect to sign in" do
        post :POST_verify_twilio_verify_installation
        expect(response).to redirect_to(new_user_session_path)
      end

      it "POST #disable_twilio_verify should redirect to sign in" do
        post :POST_disable_twilio_verify
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "with a logged in user" do
      before(:each) { sign_in(user) }

      describe "GET #enable_twilio_verify" do
        it "should render enable twilio verify view if user isn't enabled" do
          user.update_attribute(:twilio_verify_enabled, false)
          get :GET_enable_twilio_verify
          expect(response).to render_template("enable_twilio_verify")
        end

        it "should redirect and set flash if twilio verify is already enabled" do
          user.update_attribute(:twilio_verify_enabled, true)
          get :GET_enable_twilio_verify
          expect(response).to redirect_to(root_path)
          expect(flash[:notice]).not_to be nil
        end
      end

      describe "POST #enable_twilio_verify" do
        let!(:user) { create :user }

        describe 'when twilio verify is successfully enabled for the user' do
          before { post :POST_enable_twilio_verify }

          it 'should enable the user' do
            user.reload
            expect(user.twilio_verify_enabled?).to be true
          end

          it 'should redirect to the verification page' do
            expect(response).to redirect_to(user_verify_twilio_verify_installation_path)
          end
        end

        describe 'when twilio verify cannot be enabled for the user' do
          before do
            expect_any_instance_of(User).to receive(:update).with(twilio_verify_enabled: true).and_return false
            post :POST_enable_twilio_verify
          end

          it 'should set an error flash' do
            expect(flash[:error]).to be_present
          end

          it 'should redirect' do
            expect(response).to redirect_to(root_path)
          end
        end
      end

      describe 'GET verify_twilio_verify_installation' do
        before { sign_in(user) }

        describe "with a user that hasn't enabled twilio verify yet" do
          let(:user) { create :user, twilio_verify_enabled: false }

          it 'should render the twilio verify verification page' do
            get :GET_verify_twilio_verify_installation
            expect(response).to render_template('verify_twilio_verify_installation')
          end
        end

        describe 'with a user that has enabled twilio verify already' do
          let(:user) { create :twilio_verify_user }

          it 'should redirect to after twilio verify verified path' do
            get :GET_verify_twilio_verify_installation
            expect(response).to redirect_to root_path
          end
        end
      end

      describe "POST verify_twilio_verify_installation" do
        let(:token) { "000000" }

        describe "with a user that has enabled twilio verify already" do
          let(:user) { create :twilio_verify_user }

          it "should redirect to after authy verified path" do
            post :POST_verify_twilio_verify_installation, :params => { :token => token }
            expect(response).to redirect_to root_path
          end
        end

        describe "with a user that has an authy id but isn't enabled", skip: true do
          before(:each) { user.update_attribute(:twilio_verify_enabled, false) }

          describe "successful verification" do
            before(:each) do
              expect(TwilioVerifyService).to receive(:verify).with({
                :id => user.authy_id,
                :token => token,
                :force => true
              }).and_return(double("TwilioVerify::Response", :ok? => true))
              post :POST_verify_twilio_verify_installation, :params => { :token => token, :remember_device => '0' }
            end

            it "should enable authy for user" do
              user.reload
              expect(user.twilio_verify_enabled).to be true
            end

            it "should set {resource}_twilio_verify_token_checked in the session" do
              expect(session["user_twilio_verify_token_checked"]).to be true
            end

            it "should set a flash notice and redirect" do
              expect(response).to redirect_to(root_path)
              expect(flash[:notice]).to eq('Two factor authentication was enabled')
            end

            it "should not set a remember_device cookie" do
              expect(cookies["remember_device"]).to be_nil
            end
          end

          describe "successful verification with remember device" do
            before(:each) do
              expect(TwilioVerifyService).to receive(:verify).with({
                :id => user.authy_id,
                :token => token,
                :force => true
              }).and_return(double("TwilioVerify::Response", :ok? => true))
              post :POST_verify_twilio_verify_installation, :params => { :token => token, :remember_device => '1' }
            end

            it "should enable authy for user" do
              user.reload
              expect(user.twilio_verify_enabled).to be true
            end
            it "should set {resource}_twilio_verify_token_checked in the session" do
              expect(session["user_twilio_verify_token_checked"]).to be true
            end
            it "should set a flash notice and redirect" do
              expect(response).to redirect_to(root_path)
              expect(flash[:notice]).to eq('Two factor authentication was enabled')
            end

            it "should set a signed remember_device cookie" do
              jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
              cookie = jar.signed["remember_device"]
              expect(cookie).not_to be_nil
              parsed_cookie = JSON.parse(cookie)
              expect(parsed_cookie["id"]).to eq(user.id)
            end
          end

          describe "unsuccessful verification" do
            before(:each) do
              expect(TwilioVerifyService).to receive(:verify).with({
                :id => user.authy_id,
                :token => token,
                :force => true
              }).and_return(double("TwilioVerify::Response", :ok? => false))
              post :POST_verify_twilio_verify_installation, :params => { :token => token }
            end

            it "should not enable authy for user" do
              user.reload
              expect(user.twilio_verify_enabled).to be false
            end

            it "should set an error flash and render verify_twilio_verify_installation" do
              expect(response).to render_template('verify_twilio_verify_installation')
              expect(flash[:error]).to eq('Something went wrong while enabling two factor authentication')
            end
          end

          describe "unsuccessful verification with qr codes turned on" do
            before(:each) do
              Devise.twilio_verify_enable_qr_code = true
            end

            after(:each) do
              Devise.twilio_verify_enable_qr_code = false
            end

            it "should hit API for a QR code" do
              expect(TwilioVerifyService).to receive(:verify).with({
                :id => user.authy_id,
                :token => token,
                :force => true
              }).and_return(double("TwilioVerify::Response", :ok? => false))
              expect(TwilioVerifyService).to receive(:request_qr_code).with(
                :id => user.authy_id
              ).and_return(double("TwilioVerify::Request", :qr_code => 'https://example.com/qr.png'))

              post :POST_verify_twilio_verify_installation, :params => { :token => token }
              expect(response).to render_template('verify_twilio_verify_installation')
              expect(assigns[:twilio_verify_qr_code]).to eq('https://example.com/qr.png')
            end
          end
        end
      end

      describe 'POST disable_twilio_verify' do
        describe "successfully" do
          before(:each) do
            cookies.signed[:remember_device] = {
              :value => {expires: Time.now.to_i, id: user.id}.to_json,
              :secure => false,
              :expires => User.twilio_verify_remember_device.from_now
            }

            post :POST_disable_twilio_verify
          end

          it 'does not delete the users authy id' do
            expect(user.authy_id).to be_present
          end

          it "should disable 2FA" do
            user.reload
            expect(user.twilio_verify_enabled).to be false
          end

          it "should forget the device cookie" do
            expect(response.cookies[:remember_device]).to be nil
          end

          it "should set a flash notice and redirect" do
            expect(flash.now[:notice]).to eq("Two factor authentication was disabled")
            expect(response).to redirect_to(root_path)
          end
        end

        describe "unsuccessfully" do
          before(:each) do
            cookies.signed[:remember_device] = {
              :value => {expires: Time.now.to_i, id: user.id}.to_json,
              :secure => false,
              :expires => User.twilio_verify_remember_device.from_now
            }

            expect_any_instance_of(User).to receive(:save).and_return false
            post :POST_disable_twilio_verify
          end

          it "should not disable 2FA" do
            user.reload
            expect(user.authy_id).not_to be nil
            expect(user.twilio_verify_enabled).to be true
          end

          it "should not forget the device cookie" do
            expect(cookies[:remember_device]).not_to be_nil
          end

          it "should set a flash error and redirect" do
            expect(flash[:error]).to eq("Something went wrong while disabling two factor authentication")
            expect(response).to redirect_to(root_path)
          end
        end
      end
    end
  end

  describe "requesting authentication tokens" do
    describe "without a user" do
      it "Should not request sms if user couldn't be found" do
        expect(TwilioVerifyService).not_to receive(:request_sms)

        post :request_sms

        expect(response.media_type).to eq('application/json')
        body = JSON.parse(response.body)
        expect(body['sent']).to be false
        expect(body['message']).to eq("User couldn't be found.")
      end
    end

    describe '#request_sms' do
      let(:user) { create :twilio_verify_user }

      before do
        expect(TwilioVerifyService).to receive(:send_sms_token)
          .with(user.mobile_phone)
          .and_return(double("TwilioVerify::Response", :status=> "pending"))
      end

      describe 'with a logged in user' do
        before(:each) { sign_in user }

        it "should send an SMS and respond with JSON" do
          post :request_sms
          expect(response.media_type).to eq('application/json')
          body = JSON.parse(response.body)

          expect(body['sent']).to be_truthy
          expect(body['message']).to eq("Token was sent.")
        end
      end

      describe "with a user_id in the session" do
        before(:each) { session["user_id"] = user.id }

        it "should send an SMS and respond with JSON" do
          post :request_sms
          expect(response.media_type).to eq('application/json')
          body = JSON.parse(response.body)

          expect(body['sent']).to be_truthy
          expect(body['message']).to eq 'Token was sent.'
        end
      end
    end
  end
end
