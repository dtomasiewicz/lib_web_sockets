require 'digest/sha1'
require 'base64'

module LibWebSockets

  class ServerConnection < Connection

    # if multiple supported versions are suggested by the client, the one to appear
    # first in this list is used
    VERSIONS = [Handler::Server13]

    def handshake_recv(data)
      response = HTTP::Response.new '101 Switching Protocols'

      begin
        request = HTTP::Request.parse data
        if client_version = request['Sec-WebSocket-Version']
          client_versions = client_version.split(',').map &:strip
          VERSIONS.each do |version|
            if client_versions.include? version::NAME
              self.handler = version.handshake self, request, response
              break
            end
          end

          if self.handler
            open!
          else
            raise Handler::InvalidHandshake, 'Version(s) not supported'
          end
        else
          raise Handler::InvalidHandshake, '|Sec-WebSocket-Version| missing'
        end
      rescue HTTP::Message::Malformed, Handler::InvalidHandshake => e
        response = HTTP::Response.new('400 Bad Request', e.message, {
          'Sec-WebSocket-Version' => self.class::VERSIONS.map{|v| v::NAME}.join(',')
        })
      end

      send_data response.to_s
    end

  end

end