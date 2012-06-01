module LibWebSockets
  module Handler

    class Server13 < Base
      
      NAME = '13'
      FRAME_CLASS = LibWebSockets::Frame::Frame13
      ACCEPT_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

      def initialize(conn, host, origin)
        super(conn)
        @host, @origin = host, origin
      end

      def ping(data = "")
        conn.send_data FRAME_CLASS.new(:ping, data).to_s
      end

      def self.handshake(conn, req, res)
        # |Host| requirement per 4.2.1-2
        raise InvalidHandshake, '|Host| missing in client handshake' unless host = req['Host']

        # |Connection| requirement per 4.2.1-4
        if connection = req['Connection']
          raise InvalidHandshake, '|Connection| is not valid' unless connection.downcase == 'upgrade'
        else
          raise InvalidHandshake, '|Connection| missing in client handshake'
        end

        # |Upgrade| requirement per 4.2.1-3
        if upgrade = req['Upgrade']
          raise InvalidHandshake, '|Upgrade| is not valid' unless upgrade.downcase == 'websocket'
        else
          raise InvalidHandshake, '|Upgrade| missing in client handshake'
        end

        # |Sec-WebSocket-Key| requirement per 4.2.1-5
        if key = req['Sec-WebSocket-Key']
          res_key = Digest::SHA1.base64digest key+ACCEPT_GUID
        else
          raise InvalidHandshake, '|Sec-WebSocket-Key| missing in client handshake'
        end

        # TODO optional:
        #   - protocol (4.2.1-8)
        #   - extensions (4.2.1-9)
        #   - cookies etc (4.2.1-10)

        # REQUEST IS NOW CONSIDERED VALID

        origin = req['Origin'] ? req['Origin'].downcase : nil

        res['Upgrade'] = 'websocket'
        res['Connection'] = 'Upgrade'
        res['Sec-WebSocket-Version'] = NAME
        res['Sec-WebSocket-Accept'] = res_key

        new(conn, host, origin)
      end

      def recv_frame(frame)
        case frame.op
        when :continue, :text, :binary
          conn.message_frame! frame

          if conn.buffer_message?
            if frame.continue?
              raise BadFrameSequence, 'unexpected continuation frame' unless @message
              @message << frame
            else
              @message = [frame]
            end

            if frame.fin?
              conn.message! FRAME_CLASS.join(@message)
              @message = nil
            end
          end
        when :close
          conn.send FRAME_CLASS.new(:close).to_s if conn.open?
          conn.closed!
        when :ping
          conn.send_data FRAME_CLASS.new(:pong, frame.payload).to_s
        when :pong
          conn.pong!
        else
          raise BadFrameOp, "unsupported/unimplemented frame op: #{frame.op}"
        end
      end

      def close
        conn.send_data FRAME_CLASS.new(:close).to_s
        conn.closing!
      end

    end

  end
end