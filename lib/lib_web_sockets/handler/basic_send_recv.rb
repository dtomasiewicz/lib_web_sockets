module LibWebSockets
  module Handler

    module BasicSendRecv

      # Send a WebSocket message. The message type will be determined by the
      # encoding of the _message_ string. The registered data_sender block will
      # be invoked to send raw data.
      def send(message)
        raise LibWebSockets::Connection::InvalidMessage, 'not a String' unless message.kind_of? String
        raise LibWebSockets::Connection::InvalidState, to_s unless open?

        frame_class.for_message(message).each do |frame|
          send_data frame.to_s
        end
      end

      # Process (binary) data that is received through the I/O source.
      def recv(data)
        frame_class.parse_all(data).each do |frame|
          recv_frame frame
        end
      end

    end

  end
end