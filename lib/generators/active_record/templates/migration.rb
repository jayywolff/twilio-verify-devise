class DeviseTwilioVerifyAddTo<%= table_name.camelize %> < ActiveRecord::Migration<%= migration_version %>
  def self.up
    change_table :<%= table_name %> do |t|
      t.string    :authy_id
      t.datetime  :last_sign_in_with_twilio_verify
      t.boolean   :twilio_verify_enabled, :default => false
      t.string    :twilio_totp_factor_sid
    end
  end

  def self.down
    change_table :<%= table_name %> do |t|
      t.remove :authy_id, :last_sign_in_with_twilio_verify, :twilio_verify_enabled, :twilio_totp_factor_sid
    end
  end
end

