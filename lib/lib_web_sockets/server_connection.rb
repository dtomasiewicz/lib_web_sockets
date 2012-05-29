require 'digest/sha1'
require 'base64'

module LibWebSockets

  class ServerConnection < Connection

    ACCEPT_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    attr_reader :host, :origin

    # Implements the server's Opening Handshake as detailed in 4.2
    # TODO 4.2.2
    def opening_recv_data(data)
      err_headers = {'Sec-WebSocket-Version' => '13'}
      begin
        req = HTTP::Request.parse data

        # |Sec-WebSocket-Version| requirement per 4.2.1-6
        # This should be checked first, since some of the other rules are version-dependent
        if version = req['Sec-WebSocket-Version']
          versions = version.split(',').map &:strip
          unless res_version = (LibWebSockets::VERSIONS & versions).first
            raise InvalidData, "none of the supplied WebSocket versions are supported"
          end
        else
          raise InvalidData, '|Sec-WebSocket-Version| missing in client handshake'
        end

        # |Host| requirement per 4.2.1-2
        raise InvalidData, '|Host| missing in client handshake' unless @host = req['Host']

        # |Connection| requirement per 4.2.1-4
        if connection = req['Connection']
          raise InvalidData, '|Connection| is not valid' unless connection.downcase == 'upgrade'
        else
          raise InvalidData, '|Connection| missing in client handshake'
        end

        # |Upgrade| requirement per 4.2.1-3
        if upgrade = req['Upgrade']
          raise InvalidData, '|Upgrade| is not valid' unless upgrade.downcase == 'websocket'
        else
          raise InvalidData, '|Upgrade| missing in client handshake'
        end

        # |Sec-WebSocket-Key| requirement per 4.2.1-5
        if key = req['Sec-WebSocket-Key']
          decoded_key = Base64.decode64 key
          raise InvalidData, '|Sec-WebSocket-Key| is not valid' unless decoded_key.length == 16
          res_accept = Digest::SHA1.base64digest key+ACCEPT_GUID
        else
          raise InvalidData, '|Sec-WebSocket-Key| missing in client handshake'
        end

        # TODO optional:
        #   - protocol (4.2.1-8)
        #   - extensions (4.2.1-9)
        #   - cookies etc (4.2.1-10)

        # REQUEST IS NOW CONSIDERED VALID

        @origin = req['Origin'].downcase
        res = Response.new '101 Switching Protocols'
        res['Upgrade'] = 'websocket'
        res['Connection'] = 'Upgrade'
        res['Sec-WebSocket-Version'] = res_version
        res['Sec-WebSocket-Accept'] = res_accept
        send_data res.to_s

        open!
      rescue => e
        # required per section 4.2.1
        send_data Response.new('400 Bad Request', e.message, err_headers).to_s
        raise e
      end
    end

  end

end