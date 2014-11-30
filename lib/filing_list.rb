module FISC
  class FilingList

    attr_reader :page_number

    def initialize(page_number)
      @page_number = page_number
    end

    def url
      "#{FISC::DOMAIN}/public-filings?field_case_reference_nid=All&page=#{page_number}"
    end

    def html
      @html ||= Typhoeus.get(url).body
    end

    def doc
      @doc ||= Nokogiri::HTML html
    end

    def last_page?
      !!doc.at("li.pager-last")
    end

    def rows
      doc.css("tbody tr")
    end

    def filings
      @filings ||= rows.map { |node| Filing.from_hash(Row.new(node).to_hash) }
    end

    def inspect
      "#<FISC:FilingList page_number=#{page_number} filings=#{filings.count}>"
    end
  end
end
