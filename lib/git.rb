require 'rugged'

module FISC
  module Git

    # ensure git repo/branch for docket is checked out and ready
    # assumptions: remote exists, and branch exists on remote
    def self.init!
      puts "[git] Initializing docket directory..."

      if !File.exists?("docket")
        # puts "[git] Cloning docket branch..."
        system "git clone --branch #{FISC.config['docket']['branch']} --single-branch #{FISC.config['docket']['remote']} docket"
      end
      # puts "[git] Switching to docket branch..."
      system "cd docket && git checkout #{FISC.config['docket']['branch']}"
      # puts "[git] Pulling latest changes..."
      system "cd docket && git pull --no-edit"
      puts
    end

    def self.changed?
      Rugged::Repository.new("docket").status do |file, status_data|
        if (status_data & [:worktree_modified, :worktree_new]).any?
          return true
        end
      end

      false
    end

    # only commits and pushes the contents of `docket/filings`
    def self.save!(message)
      %x[cd docket && git add filings]
      %x[cd docket && git commit -m "#{message}"]

      repo = Rugged::Repository.new "docket"
      sha = repo.last_commit.oid
      puts "[git][#{sha}] Committed."
      %x[cd docket && git push]
      puts "[git][#{sha}] Pushed."
      puts

      sha
    end
  end
end