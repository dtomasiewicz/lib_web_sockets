module LibWebSockets
  module HTTP

    class Response < Message

      attr_accessor :status

      def initialize(status = '200 OK', *msg_args)
        super(*msg_args)
        @status = status.frozen? ? status : status.dup
      end

      def to_s
        "HTTP/1.1 #{status}\r\n" << super
      end

      protected

      def self.parse_lines(lines)
        raise 'no status line' unless status_line = lines.shift
        status_line.chomp! CRLF
        http_version, status = status_line.split(/ /, 2)
        raise Malformed, "invalid HTTP version: #{http_version}" unless http_version == 'HTTP/1.1'
        return status, *super(lines)
      end

    end

  end
end