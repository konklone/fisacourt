require 'clockwork'

module Clockwork

  handler do |job|
    if job == "fisa-test"
      puts "Running #{job}"
      system "bundle exec ruby fisa.rb test"
    end
  end

  every(1.minute, 'fisa-test')
end