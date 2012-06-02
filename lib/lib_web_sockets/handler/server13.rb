module LibWebSockets
  module Handler

    # implements the WebSockets protocol as described in RFC 6455
    module Server13

      include BasicSendRecv
      
      NAME = '13'
      ACCEPT_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
      Frame = LibWebSockets::Frame::Frame13

      def self.handshake(req, res)
        # |Host| requirement per 4.2.1-2
        raise FailedHandshake, '|Host| missing in client handshake' unless host = req['Host']

        # |Connection| requirement per 4.2.1-4
        if connection = req['Connection']
          raise FailedHandshake, '|Connection| is not valid' unless connection.downcase == 'upgrade'
        else
          raise FailedHandshake, '|Connection| missing in client handshake'
        end

        # |Upgrade| requirement per 4.2.1-3
        if upgrade = req['Upgrade']
          raise FailedHandshake, '|Upgrade| is not valid' unless upgrade.downcase == 'websocket'
        else
          raise FailedHandshake, '|Upgrade| missing in client handshake'
        end

        # |Sec-WebSocket-Key| requirement per 4.2.1-5
        if key = req['Sec-WebSocket-Key']
          res_key = Digest::SHA1.base64digest key+ACCEPT_GUID
        else
          raise FailedHandshake, '|Sec-WebSocket-Key| missing in client handshake'
        end

        # TODO optional:
        #   - protocol (4.2.1-8)
        #   - extensions (4.2.1-9)
        #   - cookies etc (4.2.1-10)

        # REQUEST IS NOW CONSIDERED VALID

        res['Upgrade'] = 'websocket'
        res['Connection'] = 'Upgrade'
        res['Sec-WebSocket-Version'] = NAME
        res['Sec-WebSocket-Accept'] = res_key

        return :host => host, :origin => req['Origin'] ? req['Origin'].downcase : nil
      end

      attr_reader :host, :origin

      def handler_init(data)
        @host, @origin = data[:host], data[:origin]
        open!
      end

      # Ping the remote host, invoking the (optional) _pong_callback_ when a Pong
      # response is received. A _payload_ string may be supplied, but it will be 
      # sent as-is (NOT encoded to UTF-8) regardless of its encoding.
      #
      # Only one _pong_callback_ may be registered at a time, and sending another
      # Ping before a Pong is received will result in the existing callbacks being
      # unregistered (even if no new callback is supplied).
      def ping(data = "", &pong_callback)
        @pong_callback = pong_callback
        raw_send! Frame.new(:ping, data).to_s
      end

      # Close a Connection. This will only initiate the closing handshake; the 
      # _on_close_ handler will be invoked after the handshake is complete.
      def close(status = 1000, reason = nil)
        raise InvalidState, 'connection is not open' unless state? [:connecting, :open]
        @state = :closing
        if status
          data = [status]
          format = 'n'
          if reason
            reason = reason.encode Frame::TEXT_ENCODING unless reason.encoding == Frame::TEXT_ENCODING
            data << reason
            format << "A#{reason.bytesize}"
          end
          payload = data.pack format
        else
          payload = ""
        end
        raw_send! Frame.new(:close, payload).to_s
      end

      def closing?; @state == :closing; end

      private

      # required for BasicSendRecv
      def frame_class
        Frame
      end

      # required for BasicSendRecv
      def recv_frame(frame)
        case frame.op
        when :continuation, :text, :binary
          message_frame! frame

          if buffer_message?
            if frame.continuation?
              raise BadFrameSequence, 'unexpected continuation frame' unless @message
              @message << frame
            else
              @message = [frame]
            end

            if frame.fin?
              message! Frame.join(@message)
              @message = nil
            end
          end
        when :close
          status = reason = nil
          if frame.payload.length >= 2
            status = frame.payload[0, 2].unpack 'n'
            reason = frame.payload[2..-1].force_encoding Frame::TEXT_ENCODING
          end
          raw_send! Frame.new(:close, frame.payload).to_s if open?
          closed! status, reason
        when :ping
          raw_send! Frame.new(:ping, frame.payload).to_s
        when :pong
          # must nullify @pong_callback BEFORE calling in case the handler
          # sends another ping
          if handler = @pong_callback
            @pong_callback = nil
            handler.call
          end
        else
          raise BadFrameOp, "unsupported/unimplemented frame op: #{frame.op}"
        end
      end

    end

  end
end