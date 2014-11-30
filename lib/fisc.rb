# stdlib
require 'uri'
require 'time'
require 'logger'
require 'yaml'

# 3d party
require 'nokogiri'
require 'nokogiri'
require 'typhoeus'
require 'change_agent'

# FISC
require_relative 'filing'
require_relative 'filing_list'
require_relative 'filing_list_row'

module FISC

  DOMAIN = "www.fisc.uscourts.gov"

  def self.check
    FISC::App.new.check
  end

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.archive
    @archive ||= ChangeAgent.init "docket"
  end

  class App

    def config
      @config ||= YAML.load(File.read('config.yml'))
    rescue
      {}
    end
    alias_method :options, :config

    def check
      FISC.logger.debug "Starting check"
      page = FilingList.new(1)
      while !page.last_page? do
        FISC.logger.debug "Starting Page #{page.page_number} with #{page.filings.count} filings"
        page.filings.each do |filing|

          # Burn it down mode
          if config[:everything]
            FISC.logger.debug "Saving #{filing.id} because YOLO"
            filing.save

          # data or PDF has never been downloaded, and so should be or
          elsif !filing.saved?
            FISC.logger.debug "Saving #{filing.id} because it's a known unknown"

          # the PDF is here, but the etag doesn't match, so re-download
          elsif filing.etag != filing.last_known_etag
            FISC.logger.debug "Saving #{filing.id} because etags don't match"
            filing.save

          # It's a unix system. We know this.
          else
            FISC.logger.debug "Skipping #{filing.id} because it's a known known"
          end
        end
        page = FilingList.new(page.page_number + 1) # page++
      end
      FISC.logger.debug "Fin."
    end
  end
end
