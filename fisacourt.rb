#!/usr/bin/env ruby

# requires bundler and rubygems, just deal
require 'rubygems'
require 'bundler/setup'

require 'safe_yaml'
require 'fileutils'
require 'open-uri'
require 'git'

# working directory should always be next to this script, to read in config.yml
FileUtils.chdir File.dirname(__FILE__)

module FISC
  def self.config
    @config ||= YAML.safe_load(File.read('config.yml'))
  end
end

# the URLs we're tracking
FISC_URL = "http://www.fisc.uscourts.gov/public-filings"

require './alerts'
Alerts.config!


# ensure git repo/branch for docket is checked out and ready
# assumptions: remote exists, and branch exists on remote
@docket = "docket"
if !File.exists?(@docket)
  puts "[git] Cloning docket branch..."
  system "git clone --branch #{FISC.config['docket']['branch']} --single-branch #{FISC.config['docket']['remote']} #{@docket}"
end
puts "[git] Switching to docket branch..."
system "cd #{@docket} && git checkout #{FISC.config['docket']['branch']}"
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
      "#{FISC_URL}?t=#{Time.now.to_i}",
      "User-Agent" => "@FISACourt, twitter.com/FISACourt, github.com/konklone/fisacourt"
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

      Alerts.admin! "Git error!"

      true
    end
  else
    puts "Nothing changed."
    false
  end

end

def changed?
  @git.diff('HEAD','fisa.html').entries.length != 0
end

if sha = check_fisa(test: (ARGV[0] == "test"), test_error: (ARGV[0] == "test_error"), use_file: (ARGV[0] == "use_file"))
  message = "Just updated with something!\n#{FISC_URL}"
  short_message = message.dup

  if FISC.config['github'] and sha.is_a?(String)
    diff_url = "https://github.com/#{FISC.config['github']}/commit/#{sha}"
    message += "\n\nLine-by-line breakdown of what changed:\n#{diff_url}"
  end

  Alerts.admin! message, short_message
  Alerts.public! message
  puts "Notified: #{message}"
end
