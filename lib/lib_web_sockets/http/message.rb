module LibWebSockets
  module HTTP

    class Message

      CRLF = "\r\n"

      class Malformed < StandardError; end

      attr_accessor :headers, :body

      def initialize(headers = {}, body = nil)
        @headers = headers.kind_of?(Headers) ? headers.dup : Headers[headers]
        @body = body
      end

      def self.parse(str)
        return new *parse_lines(str.lines(CRLF).to_a)
      end

      def to_s
        @headers.to_s << CRLF+@body.to_s
      end

      def [](name)
        @headers[name]
      end

      def []=(name, value)
        @headers[name] = value
      end

      protected

      def self.parse_lines(lines)
        headers = Headers.new
        loop do
          raise Malformed, 'no blank line after headers' unless line = lines.shift
          line.chomp! CRLF
          break if line == ""
          name, value = line.split(':', 2)
          headers.add name, strip_lws(value)
        end
        return headers, lines.join(CRLF)
      end

      # strips leading and trailing linear white-space (LWS; tabs/spaces)
      def self.strip_lws(str)
        str.dup.sub!(/^[ \t]*/, '').sub! /[ \t]*$/, ''
      end

    end

  end
end