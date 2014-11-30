require 'nokogiri'
require 'nokogiri'
require 'logger'
require 'typhoeus'
require 'change_agent'

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
      page = FilingList.new(1)
      while !page.last_page? do
        FISC.logger.debug "Starting Page #{page.page_number} with #{page.filings.count} filings"
        page.filings.each do |filing|
          # A few options:
          # 1. Burn it down mode
          # 2. data or PDF has never been downloaded, and so should be or
          # 3. the PDF is here, but the etag doesn't match, so re-download
          if config[:everything] || !filing.saved? || filing.etag != filing.last_known_etag
            FISC.logger.debug "Filing #{filing.id} is a known unkonwn"
            filing.save
          else
            FISC.logger.debug "Filing #{filing.id} is a known known"
          end
        end
        page = FilingList.new(page.page_number + 1) # page++
      end
    end
  end
end
