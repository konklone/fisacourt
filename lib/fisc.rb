require 'open-uri'
require 'nokogiri'

require './lib/alerts'
require './lib/git'
require './lib/filings'

module FISC
  URL = "http://www.fisc.uscourts.gov/public-filings"

  def self.config
    @config ||= YAML.load(File.read('config.yml'))
  end

  # use the "last" link to figure out the final page #
  # pretty brittle: it'd better be there
  def self.last_page!
    puts "Finding page number of final page..."
    first = download! FISC::Filings.url_for(page: 1)
    doc = Nokogiri::HTML first
    link = doc.at("li.pager-last").at("a")['href']
    page = link.scan(/page=(\d+)/).first.first.to_i
    puts "Last page: #{page}"
    page
  end


  def self.download!(url)
    # puts "Downloading: #{url}"
    open(
      url,
      "User-Agent" => "@FISACourt, twitter.com/FISACourt, github.com/konklone/fisacourt"
    ).read
  end

  # file had better be there
  def self.sha256(destination)
    response = `sha256sum "#{destination}"`
    response.split(/\s+/).first
  end

  # downloads a PDF with wget to the chosen place, returns a SHA-256 sum
  def self.download_pdf!(pdf_url, destination)
    `wget -q "#{pdf_url}" -O "#{destination}"`

    # puts "\tSleeping 1s to play nice..."
    sleep 1

    if File.exist?(destination)
      sha256 destination
    else
      raise Exception.new("Couldn't download #{pdf_url}")
    end
  end

  # make a HEAD request and get the current etag
  def self.etag!(url)
    response = `curl -s --head "#{url}"`
    header = response.split(/[\r\n]+/).find {|l| l =~ /ETag/i}
    return nil unless header
    etag = header.split(/:\s*/)[1].gsub("\"", "")
    etag
  end

  def self.check!(options: {})
    return "test" if options[:test]

    pages = options[:archive] ? (0..last_page!).to_a : [0]

    pages.each do |page|
      puts "[#{page}] Downloading filings..."
      if options[:use_file]
        body = File.read "./test/filings#{page}.html"
      else
        url = FISC::Filings.url_for page: page
        body = download! url
      end

      # parse filing data out of the HTML
      filings = FISC::Filings.for_page body

      # debugging convenience
      if options[:one]
        filings = [filings[0]]
      end

      # save a file for each one into the docket dir
      filings.each do |filing|
        pdf_path = FISC::Filings.pdf_path_for filing
        data_path = FISC::Filings.data_path_for filing
        sha = nil

        etag = etag! filing['file_url']
        if etag.nil?
          puts "\t[#{filing['id']}] Error looking for ETag - skipping."
          next
        end


        # possible situations:
        # 1) data or PDF has never been downloaded, and so should be
        if !File.exists?(data_path) or !File.exists?(pdf_path)
          puts "\t[#{filing['id']}] First time, downloading..."
          sha = download_pdf! filing['file_url'], pdf_path

        else
          puts "\t[#{filing['id']}] Have it, grabbing ETag..."
          old_etag = FISC::Filings.data_for(filing)['last_etag']

          # 2) the PDF is here, but the etag doesn't match, so re-download
          if (old_etag != etag)
            puts "\t[#{filing['id']}] Unmatched ETag, downloading..."
            sha = download_pdf! filing['file_url'], pdf_path

          # 3) the PDF is here and etag matches, but we asked to re-download
          elsif options[:everything]
            puts "\t[#{filing['id']}] Asked for everything, downloading..."
            sha = download_pdf! filing['file_url'], pdf_path

          # 4) none of those, so don't download, read the sha256 from disk
          else
            puts "\t[#{filing['id']}] Matched ETag, using local file..."
            sha = sha256 pdf_path
          end
        end

        puts "\t[#{filing['id']}][#{sha[0..6]}] SHA'd the PDF."
        filing['last_sha'] = sha
        filing['last_etag'] = etag

        FISC::Filings.save! filing
      end
    end

    puts
    puts "Saved current state of FISC docket."
    puts

    # we do specialexception handling here because an exception here
    # means that there *was* an update, and we should signal back to
    # the check script that there was, so it posts to the public,
    # even if there was an error talking to git afterwards.
    if !options[:archive] and (FISC::Git.changed? or options[:test_error])
      begin
        raise Exception.new("Fake git error!") if options[:test_error]
        FISC::Git.save! "The FISC has published something new."

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
