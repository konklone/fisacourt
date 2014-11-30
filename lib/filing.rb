module FISC
  class Filing

    attr_accessor :data

    def initialize(data)
      @data=data
    end

    def id
      data[:id]
    end

    def remote_path
      "/sites/default/files/#{id}"
    end

    def pdf_path
      @pdf_path ||= "filings/pdf/#{File.basename(URI.split(remote_path)[5])}.pdf"
    end

    def remote_contents
      Net::HTTP.start(FISC::DOMAIN) do |http|
        resp = http.get(remote_path)
        open(pdf_path, "wb") do |file|
          file.write(resp.body)
        end
      end
    end

    def local_contents

    end

    def data_path
      "filings/#{id}.yml"
    end

    def data
      @data ||= YAML.load_file data_path
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
      @etag ||= Net::HTTP.start(FISC::DOMAIN) do |http|
        http.head(remote_path)["ETag"].gsub('"','')
      end
    end

    def last_known_etag
      data[:etag]
    end

    def save

    end

    private

    def checksum(content)
      Digest::SHA256.hexdigest(content)
    end
  end
end
