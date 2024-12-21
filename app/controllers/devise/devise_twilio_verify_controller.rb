class Devise::DeviseTwilioVerifyController < DeviseController
  prepend_before_action :find_resource, :only => [
    :request_sms
  ]
  prepend_before_action :find_resource_and_require_password_checked, :only => [
    :GET_verify_twilio_verify, :POST_verify_twilio_verify
  ]

  prepend_before_action :check_resource_not_twilio_verify_enabled, :only => [
    :GET_verify_twilio_verify_installation, :POST_verify_twilio_verify_installation
  ]

  prepend_before_action :authenticate_scope!, :only => [
    :GET_enable_twilio_verify, :POST_enable_twilio_verify, :GET_verify_twilio_verify_installation,
    :POST_verify_twilio_verify_installation, :POST_disable_twilio_verify
  ]

  include Devise::Controllers::Helpers

  def GET_verify_twilio_verify
    render :verify_twilio_verify
  end

  # verify 2fa
  def POST_verify_twilio_verify
    if @resource.mobile_phone.blank? || params[:token].blank?
      return handle_invalid_token :verify_twilio_verify, :invalid_token
    end

    begin
      verification_check = TwilioVerifyService.verify_sms_token(@resource.mobile_phone, params[:token])
      verification_check = verification_check.status == 'approved'
    rescue Twilio::REST::RestError
      verification_check = false
    end

    # Reproduce authy functionality of being able to verify 2FA via SMS or TOTP
    # not ideal as there could be network delays, but there is currently no alternative
    if !verification_check && @resource.twilio_totp_factor_sid.present?
      verification_check = TwilioVerifyService.verify_totp_token(@resource, params[:token])
      verification_check = verification_check.status == 'approved'
    end

    if verification_check
      remember_device(@resource.id) if params[:remember_device].to_i == 1
      remember_user
      record_twilio_verify_authentication
      respond_with resource, :location => after_sign_in_path_for(@resource)
    else
      handle_invalid_token :verify_twilio_verify, :invalid_token
    end
  end

  def GET_enable_twilio_verify
    if resource.twilio_verify_enabled?
      set_flash_message(:notice, :already_enabled)
      redirect_to after_twilio_verify_enabled_path_for(resource)
    else
      render :enable_twilio_verify
    end
  end

  # enable 2fa
  def POST_enable_twilio_verify
    if resource.update(twilio_verify_enabled: true)
      redirect_to [resource_name, :verify_twilio_verify_installation] and return
    else
      set_flash_message(:error, :not_enabled)
      redirect_to after_twilio_verify_enabled_path_for(resource) and return
    end
  end

  # Disable 2FA
  def POST_disable_twilio_verify
    resource.assign_attributes(twilio_verify_enabled: false)
    if resource.save(validate: false)
      forget_device
      set_flash_message(:notice, :disabled)
    else
      set_flash_message(:error, :not_disabled)
    end

    redirect_to after_twilio_verify_disabled_path_for(resource)
  end

  def GET_verify_twilio_verify_installation
    if resource_class.twilio_verify_enable_qr_code
      #response = Authy::API.request_qr_code(id: resource.authy_id)
      #@twilio_verify_qr_code = response.qr_code
    end
    render :verify_twilio_verify_installation
  end

  def POST_verify_twilio_verify_installation
    if @resource.mobile_phone.blank? || params[:token].blank?
      return handle_invalid_token :verify_twilio_verify_installation, :not_enabled
    end

    verification_check = TwilioVerifyService.verify_sms_token(@resource.mobile_phone, params[:token])

    self.resource.twilio_verify_enabled = verification_check.status == 'approved'

    if verification_check.status == 'approved' && self.resource.save
      remember_device(@resource.id) if params[:remember_device].to_i == 1
      record_twilio_verify_authentication
      set_flash_message(:notice, :enabled)
      redirect_to after_twilio_verify_verified_path_for(resource)
    else
      if resource_class.twilio_verify_enable_qr_code
        #response = Authy::API.request_qr_code(id: resource.authy_id)
        #@twilio_verify_qr_code = response.qr_code
      end
      handle_invalid_token :verify_twilio_verify_installation, :not_enabled
    end
  end

  def request_sms
    if @resource.blank? || @resource.mobile_phone.blank?
      render :json => {:sent => false, :message => "User couldn't be found."}
      return
    end

    verification = TwilioVerifyService.send_sms_token(@resource.mobile_phone)
    success = verification.status == 'pending'

    render json: {
      sent: success,
      message: success ? 'Token was sent.' : 'Token was not sent, please try again.'
    }
  end

  private

  def authenticate_scope!
    send(:"authenticate_#{resource_name}!", :force => true)
    self.resource = send("current_#{resource_name}")
    @resource = resource
  end

  def find_resource
    @resource = send("current_#{resource_name}")

    if @resource.nil?
      @resource = resource_class.find_by_id(session["#{resource_name}_id"])
    end
  end

  def find_resource_and_require_password_checked
    find_resource

    if @resource.nil? || session[:"#{resource_name}_password_checked"].to_s != "true"
      redirect_to invalid_resource_path
    end
  end

  def check_resource_not_twilio_verify_enabled
    if resource.twilio_verify_enabled
      redirect_to after_twilio_verify_verified_path_for(resource)
    end
  end

  protected

  def after_twilio_verify_enabled_path_for(resource)
    root_path
  end

  def after_twilio_verify_verified_path_for(resource)
    after_twilio_verify_enabled_path_for(resource)
  end

  def after_twilio_verify_disabled_path_for(resource)
    root_path
  end

  def invalid_resource_path
    root_path
  end

  def handle_invalid_token(view, error_message)
    if @resource.respond_to?(:invalid_twilio_verify_attempt!) && @resource.invalid_twilio_verify_attempt!
      after_account_is_locked
    else
      set_flash_message(:error, error_message)
      render view
    end
  end

  def after_account_is_locked
    sign_out_and_redirect @resource
  end

  def remember_user
    if session.delete("#{resource_name}_remember_me") == true && @resource.respond_to?(:remember_me=)
      @resource.remember_me = true
    end
  end
end
