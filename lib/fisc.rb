require 'safe_yaml'
require 'open-uri'

require './lib/alerts'
require "./lib/git"

module FISC
  URL = "http://www.fisc.uscourts.gov/public-filings"

  def self.config
    @config ||= YAML.safe_load(File.read('config.yml'))
  end

  def self.url_for(page)
    # includes both docket activity and correspondence
    url = URL
    url << "?field_case_reference_nid=All"
    url << "&page=#{page}"
    url << "&t=#{Time.now.to_i}"
    url
  end


  def self.download!(page: 1)
    open(
      url_for(page),
      "User-Agent" => "@FISACourt, twitter.com/FISACourt, github.com/konklone/fisacourt"
    ).read
  end

  def self.check!(options: {})
    return "test" if options[:test]

    if options[:use_file]
      body = File.read "./test/filings.html"
    else
      puts "Downloading public filings..."
      body = download!

    end

    filings_from_body! body

    File.open("docket/fisa.html", "w") {|file| file.write body}


    puts "Saved current state of FISC docket."

    if FISC::Git.changed? or options[:test_error]
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
