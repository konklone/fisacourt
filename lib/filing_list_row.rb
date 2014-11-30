module FISC
  class FilingList
    class Row
      def initialize(node)
        @node = node
      end

      def posted_on
        Time.parse(cells[0].at("span")['content']).strftime("%Y-%m-%d")
      end

      def title
        cells[1].text.strip
      end

      def relative_url
        cells[1].css("a").first['href']
      end

      def landing_url
        URI.join("http://#{FISC::DOMAIN}/public-filings", relative_url).to_s
      end

      def id
        landing_url.split("/").last
      end

      def dockets
        cells[2].css("a").map do |a|
          {
            'name' => a.text.strip,
            'url' => URI.join(landing_url, a['href']).to_s
          }
        end
      end

      def file_url
        cells[3].css("a").first['href']
      end

      def to_hash
        {
          :file_url    => file_url,
          :title       => title,
          :dockets     => dockets,
          :posted_on   => posted_on,
          :landing_url => landing_url,
          :id          => id
        }
      end

      private

      def cells
        @cells ||= @node.css "td"
      end
    end
  end
end
