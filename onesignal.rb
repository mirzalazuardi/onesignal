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

  def response_body_hash(response_hash)
    JSON.parse(response_hash[:body])
  end

  def send_push_notif(channel: 'push', **params)
    response = conn.post('/api/v1/notifications') do |req|
      req.body = send("#{__method__}_params", channel: channel, **params).to_json
    end
    response.to_hash
  end

  def create_user(alias_label: 'external_id', **params)
    response = conn.post("/api/v1/apps/#{app_id}/users") do |req|
      req.body = send("#{__method__}_params", alias_label: alias_label, language: 'en', **params).to_json
    end
    response.to_hash
  end

  def view_user(alias_id, alias_label: 'external_id')
    response = conn.get("/api/v1/apps/#{app_id}/users/by/#{alias_label}/#{alias_id}")
    response.to_hash
  end

  def create_subscription(type, token, alias_id, alias_label: 'external_id')
    response = conn.post("/api/v1/apps/#{app_id}/users/by/#{alias_label}/#{alias_id}/subscriptions") do |req|
      req.body = send("#{__method__}_params", type, token).to_json
    end
    response.to_hash
  end

  private

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

  def create_user_params(alias_label: 'external_id', language: 'en', **params)
    params = send("#{__method__}_validation", params)
    result = {
      properties: {
        language: language
      },
      identity: { alias_label.to_sym => params[:alias_id] }
    }
    result['properties']['tags'] = params[:tags] unless params[:tags].empty?
    result['subscriptions'] = params[:subscriptions] unless params[:subscriptions].empty?
    result
  end

  def create_user_params_validation(params)
    params[:tags] ||= {}
    params[:subscriptions] ||= []
    params = params.with_indifferent_access
    raise 'alias id should be exist' if params[:alias_id].nil?

    params
  end

  # type options:
  # Email SMS iOSPush AndroidPush HuaweiPush FireOSPush
  # WindowsPush MacOSPush ChromeExtensionPush ChromePush
  # SafaryLegacyPush FirefoxPush SafariPush
  def create_subscription_params(type, token)
    {
      subscription: {
        type: type,
        token: token,
        enabled: true,
        session_time: 60,
        session_count: 1
      }
    }
  end
end


obj = Onesignal.new('your_key', 'your_app_id')
# u1 = obj.create_user(alias_id: 'user_1')
# u2 = obj.create_user(alias_id: 'user_2')
# s1 = obj.create_subscription('AndroidPush','mirza@mail.com','user_1')
# s2 = obj.create_subscription('iOSPush','wina@mail.com','user_2')
# p1 = obj.send_push_notif(to: 'user_1', messages: {en: 'hello handsome'})
# p2 = obj.send_push_notif(to: 'user_2', messages: {en: 'hello pretty'})
