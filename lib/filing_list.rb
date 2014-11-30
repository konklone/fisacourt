module FISC
  class FilingList

    attr_reader :page_number

    def initialize(page_number)
      @page_number = page_number
    end

    def url
      "http://#{FISC::DOMAIN}/public-filings?field_case_reference_nid=All&page=#{page_number}"
    end

    def html
      @html ||= open(url).read
    end

    def doc
      @doc ||= Nokogiri::HTML html
    end

    def last_page?
      link = doc.at("li.pager-last").at("a")['href']
      page_number == link.scan(/page=(\d+)/).first.first.to_i
    end

    def rows
      doc.css("tbody tr")
    end

    def filings
      @filings ||= rows.map { |r| Filing.new(Row.new(r).to_hash) }
    end
  end
end
