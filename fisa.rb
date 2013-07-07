#!/usr/bin/env ruby

require 'rubygems'

require 'yaml'
require 'fileutils'
require 'open-uri'
require 'git'

# communication mechanisms
require 'twitter'
require 'pony'
require 'twilio-rb'

# change to current dir
FileUtils.chdir File.dirname(__FILE__)

@git = Git.open './'

def config
  @config ||= YAML.load(File.read("config.yml"))
end

if config['twitter']
  Twitter.configure do |twitter|
    twitter.consumer_key = config['twitter']['consumer_key']
    twitter.consumer_secret = config['twitter']['consumer_secret']
    twitter.oauth_token = config['twitter']['oauth_token']
    twitter.oauth_token_secret = config['twitter']['oauth_token_secret']
  end
end

if config["twilio"]
  Twilio::Config.setup(
    account_sid: config['twilio']['account_sid'],
    auth_token: config['twilio']['auth_token']
  )
end

# check FISA court for updates, compare to last check
def check_fisa
  puts "Downloading FISC docket..."
  open("http://www.uscourts.gov/uscourts/courts/fisc/index.html") do |uri|
    open("fisa.html", "wt") do |file|
      file.write uri.read
      file.close
    end

    puts "Saved current state of FISC docket."

    if changed?
      @git.add "fisa.html"
      response = @git.commit "FISC docket has been updated"
      sha = @git.gcommit(response.split(/[ \[\]]/)[2]).sha
      puts "[#{sha}] Committed update"

      @git.push
      puts "[#{sha}] Pushed"

      sha
    else
      puts "Nothing changed."
      false
    end
  end
end

# notify the admin and/or the world about it
def notify_fisa(msg)
  Twitter.update(msg) if config['twitter']
  Pony.mail(config['email'].merge(body: msg)) if config['email']
  Twilio::SMS.create(to: config['twilio']['to'], from: config['twilio']['from'], body: msg) if config['twilio']

  puts "Notified: #{msg}"
end

def changed?
  @git.diff('HEAD','fisa.html').entries.length != 0
end

if sha = check_fisa
  url = "http://www.uscourts.gov/uscourts/courts/fisc/index.html"
  msg = "Just updated with something! #{url}"

  if config['github']
    diff_url = "https://github.com/#{config['github']['repo']}/commit/#{sha}"
    msg += " Here's a diff of what changed: #{diff_url}"
  end

  notify_fisa msg
end
