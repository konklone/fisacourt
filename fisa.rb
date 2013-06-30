#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'fileutils'

# install these 3 gems
require 'twitter'
require 'pony'
require 'twilio-rb'


# configuration

# change to current dir
FileUtils.chdir File.dirname(__FILE__)

def config
  @config ||= YAML.load(File.read("config.yml"))
end

FileUtils.mkdir_p "changes"
FileUtils.mkdir_p "archive"

Twitter.configure do |twitter|
  twitter.consumer_key = config['twitter']['consumer_key']
  twitter.consumer_secret = config['twitter']['consumer_secret']
  twitter.oauth_token = config['twitter']['oauth_token']
  twitter.oauth_token_secret = config['twitter']['oauth_token_secret']
end

Twilio::Config.setup(
  account_sid: config['twilio']['account_sid'],
  auth_token: config['twilio']['auth_token']
)


# check FISA court for updates, compare to last check
def check_fisa
  system "wget http://www.uscourts.gov/uscourts/courts/fisc/index.html --output-document=current.html"

  timestamp = Time.now.strftime "%Y-%m-%d-%H%M"
  system "cp current.html archive/#{timestamp}.html"

  if File.exists?("last.html")
    last = File.read("last.html")
    current = File.read "current.html"

    if last != current
      # for convenience, freeze the different ones elsewhere too
      system "cp last.html changes/#{timestamp}-last.html"
      system "cp current.html changes/#{timestamp}-current.html"

      system "mv current.html last.html"
      true
    else
      system "mv current.html last.html"
      false
    end
  else
    # first run, nothing to compare to
    puts "Initializing: just downloading data, not notifying."
    system "mv current.html last.html"
    false
  end
end

# notify the admin and/or the world about it
def notify_fisa(msg)
  Twitter.update(msg) if config['twitter']
  Pony.mail(config['email'].merge(body: msg)) if config['email']
  Twilio::SMS.create(to: config['twilio']['to'], from: config['twilio']['from'], body: msg) if config['twilio']

  puts "Notified: #{msg}"
end


if check_fisa
  notify_fisa "Just updated with something! http://www.uscourts.gov/uscourts/courts/fisc/index.html"
end