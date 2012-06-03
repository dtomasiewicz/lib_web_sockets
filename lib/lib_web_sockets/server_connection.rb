require 'digest/sha1'
require 'base64'

module LibWebSockets

  class ServerConnection < Connection

    # If multiple supported versions are suggested by the client, the one to
    # appear first in this list is used.
    VERSIONS = [Handler::Server13]

    private
    
    # Process data received through the connection's I/O source.
    def recv_data(data)
      response = HTTP::Response.new '101 Switching Protocols'
      version = init_data = nil

      begin
        request = HTTP::Request.parse data
        if client_version = request['Sec-WebSocket-Version']
          client_versions = client_version.split(',').map &:strip
          VERSIONS.each do |v|
            if client_versions.include? v::NAME
              version = v
              init_data = v.handshake request, response
              break
            end
          end
          raise Handler::FailedHandshake, 'Version(s) not supported' unless version
        else
          raise Handler::FailedHandshake, '|Sec-WebSocket-Version| missing'
        end
      rescue HTTP::Message::Malformed, Handler::FailedHandshake => e
        response = HTTP::Response.new('400 Bad Request', e.message, {
          'Sec-WebSocket-Version' => self.class::VERSIONS.map{|v| v::NAME}.join(',')
        })
      end

      send_data response.to_s
      if version
        extend version
        handler_init init_data if respond_to? :handler_init
      end
    end

  end

end