module FISC
  class Filing

    attr_accessor :data

    def initialize(data)
      @data=data
    end

    def id
      data[:id]
    end

    def pdf_id
      File.basename(URI.split(data[:file_url])[5])
    end

    def pdf_url
      "#{FISC::DOMAIN}/sites/default/files/#{pdf_id}"
    end

    def pdf_path
      "filings/pdf/#{pdf_id}.pdf"
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
      @data ||= YAML.load_file FISC.archive.get data_path
    end

    def data=(data)
      @data ||= nil
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
    end

    def last_known_etag
      data[:etag]
    end

    def save
      FISC.archive.set data_path, data
      FISC.archive.set pdf_path, remote_contents
    end

    private

    def checksum(content)
      Digest::SHA256.hexdigest(content)
    end
  end
end
