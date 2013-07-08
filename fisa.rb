#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'fileutils'
require 'open-uri'

# install these gems:
require 'git'
require 'twitter'
require 'pony'
require 'twilio-rb'
require 'pushover'

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

if config['twilio']
  Twilio::Config.setup(
    account_sid: config['twilio']['account_sid'],
    auth_token: config['twilio']['auth_token']
  )
end

if config['pushover']
  Pushover.configure do |pushover|
    pushover.user = config['pushover']['user_key']
    pushover.token = config['pushover']['app_key']
  end
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
      begin
        @git.add "fisa.html"
        response = @git.commit "FISC docket has been updated"
        sha = @git.gcommit(response.split(/[ \[\]]/)[2]).sha
        puts "[#{sha}] Committed update"

        if config['github']
          # @git.pull doesn't work
          system "git pull -q --no-edit origin #{config['github']['branch']}"

          @git.push "origin", config['github']['branch']
          puts "[#{sha}] Pushed to Github"
        end

        sha
      rescue
        puts "Error doing the git commit and push!"
        puts "Emailing admin, notifying public without SHA."

        Pony.mail(config['email'].merge(body: "Git error!")) if config['email']
        Twilio::SMS.create(to: config['twilio']['to'], from: config['twilio']['from'], body: "Git error!") if config['twilio']

        true
      end
    else
      puts "Nothing changed."
      false
    end
  end
end

# notify the admin and/or the world about it
def notify_fisa(long_msg, short_msg)

  # do in order of importance, in case it blows up in the middle
  Twilio::SMS.create(to: config['twilio']['to'], from: config['twilio']['from'], body: short_msg) if config['twilio']
  Pony.mail(config['email'].merge(body: long_msg)) if config['email']
  Twitter.update(long_msg) if config['twitter']
  Pushover.notification(title: short_msg, message: long_msg) if config['pushover']

  puts "Notified: #{long_msg}"
end

def changed?
  @git.diff('HEAD','fisa.html').entries.length != 0
end

if sha = check_fisa
  url = "http://www.uscourts.gov/uscourts/courts/fisc/index.html"
  short_msg = "Just updated with something!\n#{url}"
  long_msg = short_msg.dup

  if config['github'] and sha.is_a?(String)
    diff_url = "https://github.com/#{config['github']['repo']}/commit/#{sha}"
    long_msg += "\n\nLine-by-line breakdown of what changed:\n#{diff_url}"
  end

  notify_fisa long_msg, short_msg
end
