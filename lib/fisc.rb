require 'safe_yaml'
require 'open-uri'

require './lib/alerts'
require "./lib/git"

module FISC
  HOME_URL = "http://www.fisc.uscourts.gov"
  FILINGS_URL = "http://www.fisc.uscourts.gov/public-filings"
  CORRESPONDENCE_URL = "http://www.fisc.uscourts.gov/correspondence"

  def self.config
    @config ||= YAML.safe_load(File.read('config.yml'))
  end

  def self.check!(test: false, test_error: false, use_file: false)
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

    if FISC::Git.changed? or test_error
      begin
        raise Exception.new("Fake git error!") if test_error
        FISC::Git.save! "FISC dockets have been updated"
      rescue Exception => ex
        puts "Error doing the git commit and push! #{ex.inspect}"
        FISC::Alerts.admin! "Git error!"

        true
      end
    else
      false
    end

  end
end
