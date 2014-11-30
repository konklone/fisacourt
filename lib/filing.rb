module FISC
  class Filing

    attr_writer :data

    # init a new filing from a data hash
    def self.from_hash(hash)
      filing = self.new(hash[:id])
      filing.data = hash.merge(filing.data)
      filing
    end

    def initialize(id)
      @id = id
    end

    def id
      @id ||= data[:id]
    end

    def pdf_id
      File.basename(URI.split(data[:file_url])[5], ".pdf")
    end

    def pdf_url
      "#{FISC::DOMAIN}/sites/default/files/#{pdf_id}.pdf"
    end

    def pdf_path
      "filings/pdfs/#{pdf_id}.pdf"
    end

    def remote_contents
      @remote_contents ||= Typhoeus.get(pdf_url).body
    end

    def local_contents
      FISC.archive.get pdf_path
    end

    def data_path
      "filings/#{id}.yml"
    end

    def data
      @data ||= begin
        data = YAML.load(FISC.archive.get(data_path))
        # symbolize keys - http://stackoverflow.com/a/890864
        data.keys.each do |key|
          data[(key.to_sym rescue key) || key] = data.delete(key)
        end
        data
      end
    end

    def remote_checksum
      checksum(remote_contents)
    end

    def local_checksum
      checksum(local_contents)
    end

    def changed?
      remote_checksum != local_checksum
    end

    def saved?
      data.nil? || !local_contents.nil?
    end

    def etag
      @etag ||= Typhoeus.head(pdf_url).headers[:ETag].gsub('"', '')
    rescue
      nil
    end

    def last_known_etag
      data[:last_etag]
    end

    def last_known_checksum
      data[:last_sha]
    end

    def to_hash
      data.to_hash
    end

    def save
      FISC.archive.set data_path, data.to_yaml
      FISC.archive.set pdf_path, remote_contents
    end

    def inspect
      "#<FISC:Filing id=\"#{id}\">"
    end

    private

    def checksum(content)
      Digest::SHA256.hexdigest(content)
    end
  end
end
