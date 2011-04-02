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
require "hpricot"
require "socket"

Hpricot.buffer_size = 131072

module TinyBack

    module Services

        class TinyURL < Base

            @@ip_manager = IPManager.new "tinyurl.com", "www.tinyurl.com"

            def initialize
                @ip = @@ip_manager.get_ip
            end

            #
            # Returns the character set used by this shortener. This function
            # is probably only useful for the advance method in the base class.
            #
            def self.charset
                "0123456789abcdefghijklmnopqrstuvwxyz"
            end

            #
            # Returns the complete short-url for a given code.
            #
            def self.url code
                "http://tinyurl.com/#{canonicalize(code)}"
            end


            #
            # The code may contain:
            #   - letters (case insensitive)
            #   - numbers
            #   - dashes (ignored)
            #   - a slash (everything after the slash is ignored)
            # The canonical version may not be longer than 49 characters
            #
            def self.canonicalize code
                code = code.split("/").first.to_s # Remove everything after slash
                code.tr! "-", "" # Remove dashes
                code.downcase! # Make everything lowercase
                raise InvalidCodeError unless code.match /^[a-z0-9]{1,49}$/
                code
            end

            #
            # Fetches the given code and returns the long url or raises a
            # NoRedirectError when the code is not in use yet. Only does a HEAD
            # request at first and then switches to GET if required, unless get
            # is set to true.
            #
            def fetch code, get = false
                begin
                    socket = TCPSocket.new @ip, 80
                    method = if get
                        "GET"
                    else
                        "HEAD"
                    end
                    socket.write ["#{method} /#{code} HTTP/1.0", "Host: tinyurl.com"].join("\r\n") + "\r\n\r\n"
                    case (line = socket.gets)
                    when "HTTP/1.0 200 OK\r\n"
                        if get
                            socket.gets("\r\n\r\n")
                            data = socket.gets nil
                            begin
                                doc = Hpricot data
                            rescue Hpricot::ParseError => e
                                raise FetchError, "Could not parse HTML data (#{e.inspect})"
                            end
                            if doc.at("/html/head/title").innerText == "Redirecting..."
                                url = doc.at("/html/body").innerText
                                doc = nil
                                return url.strip unless url.nil?
                            end
                            if doc.at("html/body/table/tr/td/h1:last").innerText == "Error: TinyURL redirects to a TinyURL."
                                url = doc.at("/html/body/table/tr/td/p.intro/a").attributes["href"]
                                doc = nil
                                return url.chomp("\n") unless url.nil?
                            end
                            doc = nil
                            raise FetchError, "Could not parse URL for code #{code.inspect}"
                        else
                            socket.close
                            return fetch(code, true)
                        end
                    when "HTTP/1.0 301 Moved Permanently\r\n"
                        while (line = socket.gets)
                            case line
                            when /^Location: (.*)\r\n/
                                return $1
                            when /^X-tiny: (error) [0-9]+\.[0-9]+\r\n/
                            when /X-Powered-By: PHP\/[0-9]\.[0-9]\.[0-9]\r\n/
                            when "\r\n"
                                raise CodeBlockedError
                            end
                        end
                        raise FetchError, "Expected Location, but received #{line.inspect} for code #{code.inspect}"
                    when "HTTP/1.0 302 Found\r\n"
                        raise CodeBlockedError
                    when "HTTP/1.0 403 Forbidden\r\n"
                        raise ServiceBlockedError
                    when "HTTP/1.0 404 Not Found\r\n"
                        raise NoRedirectError
                    else
                        raise FetchError, "Expected 200/301/302/404, but received #{line.inspect} for code #{code.inspect}"
                    end
                ensure
                    socket.close if socket and not socket.closed?
                end
            end


        end

    end

end
