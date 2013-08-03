#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'fileutils'
require 'open-uri'
require 'rss'

# install these gems:
require 'git'
require 'twitter'
require 'pony'
require 'twilio-rb'
require 'pushover'

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
def check_fisa(test: false, test_error: false)
  return "test" if test

  puts "Pulling latest changes..."
  system "git pull --no-edit" # make sure local branch is tracking a remote!

  puts "Downloading FISC docket..."
  open(
    "http://www.uscourts.gov/uscourts/courts/fisc/index.html?t=#{Time.now.to_i}",
    "User-Agent" => "@FISACourt, http://twitter.com/FISACourt, https://github.com/konklone/fisa"
  ) do |uri|
    open("fisa.html", "wt") do |file|
      file.write uri.read
      file.close
    end

    puts "Saved current state of FISC docket."

    if changed? or test_error
      begin
        @git.add "fisa.html"
        response = @git.commit "FISC docket has been updated"
        sha = @git.gcommit(response.split(/[ \[\]]/)[2]).sha
        puts "[#{sha}] Committed update"

        system "git push"
        puts "[#{sha}] Pushed changes."

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
end

def notify_rss(short_msg, long_msg, *diff_url)
  format = config['rss']['feed_type']
  output_file = config['rss']['output_file']
  site_url = config['rss']['site_url']
  about = "#{site_url}/#{output_file}"
  diff_url.empty? ? diff_url = "#{site_url}/fisa.html" : diff_url = diff_url.first

  case format
  when 'atom'
    RSS::Maker.add_maker("atom", "1.0", RSS::Maker::Atom::Feed)
  when 'rss10'
    RSS::Maker.add_maker("rss10", "1.0", RSS::Maker::RSS10::Channel)
  when 'rss20'
    RSS::Maker.add_maker("rss20", "2.0", RSS::Maker::RSS20::Channel)
  else
    return
  end

  rss_feed = RSS::Maker.make(format) do |maker|
    maker.channel.author = config['rss']['author']
    maker.channel.updated = Time.now.to_s
    maker.channel.title = "FISA Court Updates"
    maker.channel.about = about
    maker.items.new_item do |item|
      item.link = diff_url
      item.title = short_msg
      item.updated = Time.now.to_s
      item.summary = long_msg
    end
  end

  File.open( output_file, 'w+' ){|f| f.write( rss_feed ); f.close }
end

# notify the admin and/or the world about it
def notify_fisa(long_msg, short_msg, diff_url)

  # do in order of importance, in case it blows up in the middle
  Twilio::SMS.create(to: config['twilio']['to'], from: config['twilio']['from'], body: short_msg) if config['twilio']
  Pony.mail(config['email'].merge(body: long_msg)) if config['email']
  Twitter.update(long_msg) if config['twitter']

  if diff_url
    Pushover.notification(title: short_msg, message: long_msg, url: diff_url) if config['pushover']
    notify_rss(short_msg, long_msg, diff_url) if config['rss']
  else
    Pushover.notification(title: short_msg, message: long_msg) if config['pushover']
    notify_rss(short_msg, long_msg) if config['rss']
  end

  puts "Notified: #{long_msg}"
end

def changed?
  @git.diff('HEAD','fisa.html').entries.length != 0
end

if sha = check_fisa(test: (ARGV[0] == "test"), test_error: (ARGV[0] == "test_error"))
  url = "http://www.uscourts.gov/uscourts/courts/fisc/index.html"
  short_msg = "Just updated with something!\n#{url}"
  long_msg = short_msg.dup
  diff_url = false

  if config['github'] and sha.is_a?(String)
    diff_url = "https://github.com/#{config['github']}/commit/#{sha}"
    long_msg += "\n\nLine-by-line breakdown of what changed:\n#{diff_url}"
  end

  notify_fisa long_msg, short_msg, diff_url
end
