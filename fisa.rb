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
require 'xmlsimple'

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
    "User-Agent" => "@FISACourt, twitter.com/FISACourt, github.com/konklone/fisa"
  ) do |uri|
    open("fisa.html", "wt") do |file|
      file.write uri.read
      file.close
    end

    puts "Saved current state of FISC docket."

    if changed? or test_error
      begin
        
        begin
          # determine changed line numbers in fisa.html
          linediffs = [ ]
          @git.diff("fisa.html", "fisa.html").each do |file_diff|
            visitingline = -100
            file_diff.patch.split("\n").each do |diffline|
              # puts diffline
              if diffline.index("@@ ") == 0
                # beginning of a diff summary
                visitingline = diffline.split(' ')[2].split(',')[0]
                if visitingline.index('+') != nil
                  visitingline = visitingline.split('+')[1].to_i - 1
                elsif visitingline.index('-') != nil
                  visitingline = visitingline.split('-')[1].to_i - 1
                end
                # puts visitingline
              elsif visitingline < 0
                next
              else
                visitingline = visitingline + 1
                if diffline.index('+') == 0
                  linediffs << visitingline
                elsif diffline.index('-') == 0
                  linediffs << visitingline
                end
              end
            end
          end

          # list headings above changed sections
          linenum = 1
          headertext = ""
          changedsections = []
          File.open("fisa.html").each do |fileline|
  
            if fileline.index("<h3") != nil
              header = XmlSimple.xml_in(fileline)
              headertext = header["content"]
            end
  
            if linediffs.index(linenum)
              unless headertext == ""
                unless changedsections.index(headertext)
                  changedsections << headertext
                end
              end
            end
  
            linenum = linenum + 1
          end

          # if any named 
          if changedsections.length > 0
            message = "FISC docket updated " + changedsections.join(", ")
          end

        rescue
        end

        @git.add "fisa.html"
        
        response = @git.commit message
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

if sha = check_fisa(test: (ARGV[0] == "test"), test_error: (ARGV[0] == "test_error"))
  url = "http://www.uscourts.gov/uscourts/courts/fisc/index.html"
  short_msg = "Just updated with something!\n#{url}"
  long_msg = short_msg.dup

  if config['github'] and sha.is_a?(String)
    diff_url = "https://github.com/#{config['github']}/commit/#{sha}"
    long_msg += "\n\nLine-by-line breakdown of what changed:\n#{diff_url}"
  end

  notify_fisa long_msg, short_msg
end
