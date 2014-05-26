require 'rugged'

module FISC
  module Git

    # ensure git repo/branch for docket is checked out and ready
    # assumptions: remote exists, and branch exists on remote
    def self.init!
      puts
      if !File.exists?("docket")
        puts "[git] Cloning docket branch..."
        system "git clone --branch #{FISC.config['docket']['branch']} --single-branch #{FISC.config['docket']['remote']} docket"
      end
      puts "[git] Switching to docket branch..."
      system "cd docket && git checkout #{FISC.config['docket']['branch']}"
      puts "[git] Pulling latest changes..."
      system "cd docket && git pull --no-edit"
      puts
    end

    def self.repo
      @repo ||= Rugged::Repository.new("docket")
    end

    def self.changed?
      new_files = []
      repo.status do |file, status_data|
        if status_data.include?(:worktree_new)
          new_files << file
        end
      end
      new_files.any?
    end

    # only commits and pushes the contents of `docket/filings`
    def self.save!(message)
      system "cd docket && git add filings"

      response = %x[git commit -m "#{message}"]
      sha = response.split(/[ \[\]]/)[2]
      puts "[#{sha}] Committed with message: #{message}"

      system "cd docket && git push"
      puts "[#{sha}] Pushed changes."

      sha
    end
  end
end