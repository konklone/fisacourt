require 'open-uri'
require 'nokogiri'
require 'net/http'
require 'nokogiri'

require_relative 'alerts'
require_relative 'git'

require_relative 'filing'
require_relative 'filing_list'
require_relative 'filing_list_row'


module FISC

  DOMAIN = "http://www.fisc.uscourts.gov"

  class App

    def config
      @config ||= YAML.load(File.read('config.yml'))
    rescue
      {}
    end
    alias_method :options, :config

    def check
      page = FilingsList.new(1)
      while !page.last_page? do

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
end
