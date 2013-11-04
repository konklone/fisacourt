#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'fileutils'
require 'git'
require 'xmlsimple'

class Dockets

  # detect and return changed dockets
  def self.changed(git)

    dockets = []

    # determine changed line numbers in fisa.html
    line_diffs = [ ]
    git.diff("fisa.html", "fisa.html").each do |file_diff|
      visiting_line = -100
      file_diff.patch.split("\n").each do |diff_line|
        if diff_line.index("@@ ") == 0
          # beginning of a diff summary
          visiting_line = diff_line.split(' ')[2].split(',')[0]
          if visiting_line.index('+') != nil
            visiting_line = visiting_line.split('+')[1].to_i - 1
          elsif visiting_line.index('-') != nil
            visiting_line = visiting_line.split('-')[1].to_i - 1
          end
        elsif visiting_line < 0
          next
        else
          visiting_line = visiting_line + 1
          if diff_line.index('+') == 0
            line_diffs << visiting_line
          elsif diff_line.index('-') == 0
            line_diffs << visiting_line
          end
        end
      end
    end

    # list headings above changed dockets
    line_num = 1
    header_text = ""

    File.open("fisa.html").each do |file_line|

      if file_line.index("<h3") != nil
        header = XmlSimple.xml_in(file_line)
        header_text = header["content"]
      end

      if line_diffs.index(line_num)
        unless header_text == ""
          unless dockets.index(header_text)
            dockets << header_text
          end
        end
      end

      line_num = line_num + 1
    end

    dockets
  rescue Exception => ex
    []
  end
end