#!/usr/bin/env ruby

require 'git'
require 'xmlsimple'

def change_detection_message(git)

  begin
    # determine changed line numbers in fisa.html
    linediffs = [ ]
    git.diff("fisa.html", "fisa.html").each do |file_diff|
      visitingline = -100
      file_diff.patch.split("\n").each do |diffline|
        if diffline.index("@@ ") == 0
          # beginning of a diff summary
          visitingline = diffline.split(' ')[2].split(',')[0]
          if visitingline.index('+') != nil
            visitingline = visitingline.split('+')[1].to_i - 1
          elsif visitingline.index('-') != nil
            visitingline = visitingline.split('-')[1].to_i - 1
          end
        elsif visitingline < 0
          next
        else
          visitingline = visitingline + 1
          if diffline.index('+') == 0
            linediffs << visitingline
          elsif diffline.index('-') == 0
            linediffs << visitingline
          end
        end
      end
    end

    # list headings above changed sections
    linenum = 1
    headertext = ""
    changedsections = []
    File.open("fisa.html").each do |fileline|
  
      if fileline.index("<h3") != nil
        header = XmlSimple.xml_in(fileline)
        headertext = header["content"]
      end
  
      if linediffs.index(linenum)
        unless headertext == ""
          unless changedsections.index(headertext)
            changedsections << headertext
          end
        end
      end
  
      linenum = linenum + 1
    end

    # if any named 
    if changedsections.length > 0
      message = "FISC docket updated " + changedsections.join(", ")
    end

  rescue
    message = "FISC docket has been updated"
  end
  
  message
end