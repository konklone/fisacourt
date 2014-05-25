require 'git'

module FISC
  module Git

    # ensure git repo/branch for docket is checked out and ready
    # assumptions: remote exists, and branch exists on remote
    def self.init!
      if !File.exists?("docket")
        puts "[git] Cloning docket branch..."
        system "git clone --branch #{FISC.config['docket']['branch']} --single-branch #{FISC.config['docket']['remote']} docket"
      end
      puts "[git] Switching to docket branch..."
      system "cd docket && git checkout #{FISC.config['docket']['branch']}"
      puts "[git] Pulling latest changes..."
      system "cd docket && git pull --no-edit"
    end

    def self.repo
      @repo ||= ::Git.open "docket"
    end

    def self.changed?
      repo.diff('HEAD','.').entries.length != 0
    end

    def self.save!(message)
      repo.add "."

      response = repo.commit message
      sha = repo.gcommit(response.split(/[ \[\]]/)[2]).sha
      puts "[#{sha}] Committed with message: #{message}"

      system "cd docket && git push"
      puts "[#{sha}] Pushed changes."

      sha
    end
  end
end