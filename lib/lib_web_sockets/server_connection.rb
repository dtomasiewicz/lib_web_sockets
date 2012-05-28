require 'digest/sha1'
require 'base64'

module LibWebSockets

  class ServerConnection < Connection

    ACCEPT_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    # opening handshake
    def opening_recv_data(data)
      data = force_text data

      begin
        req = HTTP::Request.parse data
      rescue HTTP::Message::Malformed => e
        raise InvalidData, "malformed client handshake: #{e.message}"
      end

      unless key = req['Sec-WebSocket-Key']
        raise InvalidData, "Sec-WebSocket-Key missing in client handshake"
      end

      res = HTTP::Response.new '101 Switching Protocols'
      res['Upgrade'] = 'websocket'
      res['Connection'] = 'Upgrade'
      res['Sec-WebSocket-Accept'] = Digest::SHA1.base64digest key+ACCEPT_GUID

      send_data encode_text(res.to_s)
      open!
    end

  end

end