require 'clockwork'

module Clockwork

  handler do |job|
    puts "Running #{job}"
    if job == "fisa-test"
      system "bundle exec ruby fisa.rb test"
    elsif job == "fisa"
      system "bundle exec ruby fisa.rb"
    end
  end

  every(5.minutes, 'fisa-test')
end