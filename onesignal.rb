# frozen_string_literal: true
require 'zeitwerk'
require 'faraday'
require 'pry'
require 'hash_with_indifferent_access_duplicate_warning'
loader = Zeitwerk::Loader.new
loader.setup

# frozen_string_literal: true

class Onesignal
  attr_accessor :conn
  attr_reader :app_id

  BASE_URL = 'https://onesignal.com'

  def initialize(rest_api_key, app_id)
    @app_id = app_id
    @conn = Faraday.new(
      url: BASE_URL,
      headers: {
        'Content-Type' => 'application/json; charset=utf-8',
        'accept' => 'application/json',
        'Authorization' => "Basic #{rest_api_key}"
      }
    )
  end

  def self.response_body_hash(response_hash)
    JSON.parse(response_hash[:body])
  end

  def is_app_id_valid?
    generate_random_user
    create_user(@random_user)
    result = !(view_user(@random_user)[:status] == 400)
    delete_user(@random_user)
    result
  end

  def is_rest_api_key_valid?
    generate_random_user
    result = create_user(@random_user)[:status] == 200
    delete_user(@random_user)
    result
  end

  def self.category_hash
    {
      os: %w[WindowsPush MacOSPush],
      web: %w[ChromeExtensionPush ChromePush SafariPush FirefoxPush SafaryLegacyPush],
      mobile: %w[iOSPush AndroidPush HuaweiPush FireOSPush],
      other: %w[Email SMS]
    }
  end

  def send_push_notif(channel: 'push', **params)
    response = conn.post('/api/v1/notifications') do |req|
      req.body = send("#{__method__}_params", channel: channel, **params).to_json
    end
    present_response(response)
  end

  def create_user(alias_id, alias_label: 'external_id', **params)
    response = conn.post("/api/v1/apps/#{app_id}/users") do |req|
      req.body = send("#{__method__}_params", alias_id, alias_label: alias_label, language: 'en', **params).to_json
    end
    present_response(response)
  end

  def view_user(alias_id, alias_label: 'external_id')
    response = conn.get("/api/v1/apps/#{app_id}/users/by/#{alias_label}/#{alias_id}")
    present_response(response)
  end

  def delete_user(alias_id, alias_label: 'external_id')
    response = conn.delete("/api/v1/apps/#{app_id}/users/by/#{alias_label}/#{alias_id}")
    present_response(response)
  end

  def create_subscription(type, token, alias_id, alias_label: 'external_id')
    response = conn.post("/api/v1/apps/#{app_id}/users/by/#{alias_label}/#{alias_id}/subscriptions") do |req|
      req.body = send("#{__method__}_params", type, token).to_json
    end
    present_response(response)
  end

  private

  def generate_random_user
    @random_user ||= SecureRandom.uuid
  end

  def present_response(response)
    r = response.to_hash
    r[:body] = self.class.response_body_hash(r)
    r.with_indifferent_access
  end

  def credential_hash
    {
      app_id: app_id
    }
  end

  def send_push_notif_params(channel: 'push', **params)
    params = send("#{__method__}_validation", params)
    result = {
      include_aliases: { external_id: params[:to] },
      target_channel: channel,
      contents: params[:contents] # { contents: { en: 'hello', my: 'Halo' } } #example
    }
    result.merge!(params[:headings]) unless params[:headings].empty?
    result.merge!(params[:data]) unless params[:data].empty?
    result.merge!(credential_hash)
  end

  def send_push_notif_params_validation(params)
    params[:data] ||= {}
    params[:headings] ||= {}
    params[:contents] ||= {}
    params[:to] ||= []
    params = params.with_indifferent_access
    raise 'to should be exist at least one value in array' if check_to(params[:to])
    raise 'contents should be exist in hash' if params[:contents].empty?

    params
  end

  def check_to(to)
    to.instance_of?(String) || to.empty?
  end

  # alias_id, alias_label: alias_label, language: 'en', **params
  def create_user_params(alias_id, alias_label: 'external_id', language: 'en', **params)
    result = {
      properties: {
        language: language
      },
      identity: { alias_label.to_sym => alias_id }
    }
    result['properties']['tags'] = params[:tags] unless params[:tags].nil? || params[:tags].empty?
    result['subscriptions'] = params[:subscriptions] unless params[:subscriptions].nil? || params[:subscriptions].empty?
    result
  end

  # type options:
  # Email SMS iOSPush AndroidPush HuaweiPush FireOSPush
  # WindowsPush MacOSPush ChromeExtensionPush ChromePush
  # SafaryLegacyPush FirefoxPush SafariPush
  def create_subscription_params(type, token, **params)
    params = params.with_indifferent_access
    res = {
      subscription: {
        type: type,
        token: token,
        enabled: true,
        session_time: 60,
        session_count: 1
      }
    }.with_indifferent_access
    append_optional_subscription_params(res, **params)
  end

  def append_optional_subscription_params(prev, **params)
    params.each do |k, v|
      prev[:subscription][k] = v
    end.with_indifferent_access
    prev
  end
end


obj = Onesignal.new('your_key', 'your_app_id')
# u1 = obj.create_user(alias_id: 'user_1')
# u2 = obj.create_user(alias_id: 'user_2')
# s1 = obj.create_subscription('AndroidPush','mirza@mail.com','user_1')
# s2 = obj.create_subscription('iOSPush','wina@mail.com','user_2')
# p1 = obj.send_push_notif(to: 'user_1', messages: {en: 'hello handsome'})
# p2 = obj.send_push_notif(to: 'user_2', messages: {en: 'hello pretty'})
