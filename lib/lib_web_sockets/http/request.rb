module LibWebSockets
  module HTTP

    class Request < Message

      attr_accessor :method, :request_uri

      def initialize(method = 'GET', request_uri = '/', *msg_args)
        super(*msg_args)
        @method, @request_uri = method, request_uri
      end

      def to_s
        "#{@method} #{@request_uri} HTTP/1.1\r\n" << super
      end

      protected

      def self.parse_lines(lines)
        # request line
        raise Malformed, "no request line" unless request_line = lines.shift
        request_line.chomp!
        method, request_uri, http_version = request_line.split(/ /, 3)
        raise Malformed, "invalid HTTP version: #{http_version}" unless http_version == 'HTTP/1.1'
        return method, request_uri, *super(lines)
      end

    end

  end
end