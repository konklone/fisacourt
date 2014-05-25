#!/usr/bin/env ruby

# requires bundler and rubygems, just deal
require 'rubygems'
require 'bundler/setup'

require 'safe_yaml'
require 'fileutils'
require 'open-uri'
require 'git'

# the URLs we're tracking
HOME_URL = "http://www.fisc.uscourts.gov"
FILINGS_URL = "http://www.fisc.uscourts.gov/public-filings"
CORRESPONDENCE_URL = "http://www.fisc.uscourts.gov/correspondence"


# working directory should always be next to this script, to read in config.yml
FileUtils.chdir File.dirname(__FILE__)
module FISC
  def self.config
    @config ||= YAML.safe_load(File.read('config.yml'))
  end
end

require './alerts'
FISC::Alerts.config!

require "./git"
FISC::Git.init!


# check FISA court for updates, compare to last check
def check_fisa(test: false, test_error: false, use_file: false)
  return "test" if test

  if use_file
    body = File.read "./test/filings.html"
  else
    puts "Downloading FISC docket..."
    body = open(
      "#{FILINGS_URL}?t=#{Time.now.to_i}",
      "User-Agent" => "@FISACourt, twitter.com/FISACourt, github.com/konklone/fisacourt"
    ).read
  end

  File.open("docket/fisa.html", "w") {|file| file.write body}
  File.open("docket/fisa2.html", "w") {|file| file.write body}

  puts "Saved current state of FISC docket."

  if changed? or test_error
    begin

      message = "FISC dockets have been updated"
      puts "Committing with message: #{message}"
      FISC::Git.save! message

      # test error path
      raise Exception.new("Fake git error!") if test_error

      sha
    rescue Exception => ex
      puts "Error doing the git commit and push! #{ex.inspect}"
      FISC::Alerts.admin! "Git error!"

      true
    end
  else
    puts "Nothing changed."
    false
  end

end



if sha = check_fisa(test: (ARGV[0] == "test"), test_error: (ARGV[0] == "test_error"), use_file: (ARGV[0] == "use_file"))
  message = "Just updated with something!\n#{HOME_URL}"
  short_message = message.dup

  if FISC.config['github'] and sha.is_a?(String)
    diff_url = "https://github.com/#{FISC.config['github']}/commit/#{sha}"
    message += "\n\nLine-by-line breakdown of what changed:\n#{diff_url}"
  end

  FISC::Alerts.admin! message, short_message
  FISC::Alerts.public! message
  puts "Notified: #{message}"
end
