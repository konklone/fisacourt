require 'twitter'
require 'pony'
require 'twilio-rb'
require 'pushover'

module Alerts

  def self.admin!(message, short_message = nil)
    short_message ||= (message.size > 140) ? message[0..140] : message

    # do in order of importance, in case it blows up in the middle
    Pony.mail(FISC.config['email'].merge(body: message)) if FISC.config['email']
    Twilio::SMS.create(to: FISC.config['twilio']['to'], from: FISC.config['twilio']['from'], body: short_message) if FISC.config['twilio']
    Pushover.notification(title: short_message, message: message) if FISC.config['pushover']
  end

  def self.public!(message)
    # can't use blunt 140-char check, Twitter handles URLs specially
    Twitter.update(message) if FISC.config['twitter']
  end

  def self.config!
    if FISC.config['twitter']
      Twitter.configure do |twitter|
        twitter.consumer_key = FISC.config['twitter']['consumer_key']
        twitter.consumer_secret = FISC.config['twitter']['consumer_secret']
        twitter.oauth_token = FISC.config['twitter']['oauth_token']
        twitter.oauth_token_secret = FISC.config['twitter']['oauth_token_secret']
      end
    end

    if FISC.config['twilio']
      Twilio::Config.setup(
        account_sid: FISC.config['twilio']['account_sid'],
        auth_token: FISC.config['twilio']['auth_token']
      )
    end

    if FISC.config['pushover']
      Pushover.configure do |pushover|
        pushover.user = FISC.config['pushover']['user_key']
        pushover.token = FISC.config['pushover']['app_key']
      end
    end
  end

end