# given HTML downloaded from the FISC, grabs metadata for each filing

require 'nokogiri'

module FISC

  module Filings

    def self.url_for(page: 1)
      # includes both docket activity and correspondence
      url = FISC::URL
      url << "?field_case_reference_nid=All"
      url << "&page=#{page}"
      url << "&t=#{Time.now.to_i}"
      url
    end

    # return an array of filing hashes, as pulled from a filing page
    def self.for_page(html)
      doc = Nokogiri::HTML html

      filings = []

      doc.css("tbody tr").each do |row|
        cells = row.css "td"
        posted_on = Time.parse(cells[0].at("span")['content']).strftime("%Y-%m-%d")
        title = cells[1].text.strip
        landing_url = URI.join(FISC::URL, cells[1].css("a").first['href']).to_s
        id = landing_url.split("/").last

        dockets = cells[2].css("a").map do |a|
          {
            'name' => a.text.strip,
            'url' => URI.join(FISC::URL, a['href']).to_s
          }
        end
        file_url = cells[3].css("a").first['href']

        filings << {
          'file_url' => file_url,
          'title' => title,
          'dockets' => dockets,
          'posted_on' => posted_on,
          'landing_url' => landing_url,
          'id' => id
        }
      end

      filings
    end

    # save the filing detail to a YAML file at a predictable path
    def self.save!(filing)
      dir = "docket/filings"
      FileUtils.mkdir_p dir
      path = "#{dir}/#{filing['id']}.yml"
      yaml = YAML.dump filing
      File.open(path, "w") {|file| file.write yaml}
      true
    end

    # TODO FOR LATER:
    # make another web request to the detail page for a filing,
    # stick the description onto the hash, and return the hash
    def self.fetch_detail!(filing)

    end

  end

end