#!/usr/bin/env ruby
# TinyBack - A tiny web scraper
# Copyright (C) 2010-2011 David Triendl
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

previous_code = nil
previous_urls = []

STDIN.each_line("\n") do |line|
    line.chomp!("\n")
    if line.empty?
        STDERR.puts "next"
        next
    end
    code, url = line.split("|", 2)

    if code == previous_code
        if previous_urls.include? url
            next
        else
            STDERR.puts "Duplicate URLs for code #{code.inspect}"
        end
    else
        previous_code = code
        previous_urls = []
    end
    previous_urls << url
    STDOUT.write "#{code}|#{url}\n"
end
