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

# working directory should always be next to this script, to read in config.yml
FileUtils.chdir File.dirname(__FILE__)

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

# ensure git repo/branch for docket is checked out and ready
# assumptions: remote exists, and branch exists on remote
@docket = "docket"
if !File.exists?(@docket)
  puts "[git] Cloning docket branch..."
  system "git clone --branch #{config['docket']['branch']} --single-branch #{config['docket']['remote']} #{@docket}"
end
puts "[git] Switching to docket branch..."
system "cd #{@docket} && git checkout #{config['docket']['branch']}"
puts "[git] Pulling latest changes..."
system "cd #{@docket} && git pull --no-edit"
@git = Git.open @docket


# check FISA court for updates, compare to last check
def check_fisa(test: false, test_error: false, use_file: false)
  return "test" if test

  if use_file
    body = File.read "./test-fisa.html"
  else
    puts "Downloading FISC docket..."
    body = open(
      "http://www.uscourts.gov/uscourts/courts/fisc/index.html?t=#{Time.now.to_i}",
      "User-Agent" => "@FISACourt, twitter.com/FISACourt, github.com/konklone/fisa"
    ).read
  end

  open("#{@docket}/fisa.html", "wt") do |file|
    file.write body
    file.close
  end

  puts "Saved current state of FISC docket."

  if changed? or test_error
    begin

      message = "FISC dockets have been updated"
      puts "Committing with message: #{message}"

      @git.add "fisa.html"

      response = @git.commit message
      sha = @git.gcommit(response.split(/[ \[\]]/)[2]).sha
      puts "[#{sha}] Committed update"

      system "cd #{@docket} && git push"
      puts "[#{sha}] Pushed changes."

      # test error path
      raise Exception.new("Fake git error!") if test_error

      sha
    rescue Exception => ex
      puts "Error doing the git commit and push!"
      puts "Emailing admin, notifying public without SHA."
      puts
      puts ex.inspect

      msg = "Git error!"
      Pony.mail(config['email'].merge(body: msg)) if config['email']
      Twilio::SMS.create(to: config['twilio']['to'], from: config['twilio']['from'], body: msg) if config['twilio']
      Pushover.notification(title: msg, message: msg) if config['pushover']

      true
    end
  else
    puts "Nothing changed."
    false
  end

end

# notify the admin and/or the world about it
def notify_fisa(long_msg, short_msg)

  # do in order of importance, in case it blows up in the middle
  Twilio::SMS.create(to: config['twilio']['to'], from: config['twilio']['from'], body: short_msg) if config['twilio']
  Pushover.notification(title: short_msg, message: long_msg) if config['pushover']
  Pony.mail(config['email'].merge(body: long_msg)) if config['email']
  Twitter.update(long_msg) if config['twitter']

  puts "Notified: #{long_msg}"
end

def changed?
  @git.diff('HEAD','fisa.html').entries.length != 0
end

if sha = check_fisa(test: (ARGV[0] == "test"), test_error: (ARGV[0] == "test_error"), use_file: (ARGV[0] == "use_file"))
  url = "http://www.uscourts.gov/uscourts/courts/fisc/index.html"
  short_msg = "Just updated with something!\n#{url}"
  long_msg = short_msg.dup

  if config['github'] and sha.is_a?(String)
    diff_url = "https://github.com/#{config['github']}/commit/#{sha}"
    long_msg += "\n\nLine-by-line breakdown of what changed:\n#{diff_url}"
  end

  notify_fisa long_msg, short_msg
end
