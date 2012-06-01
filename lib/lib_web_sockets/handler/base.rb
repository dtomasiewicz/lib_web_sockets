module LibWebSockets
  module Handler

    class Base

      FRAME_CLASS = LibWebSockets::Frame::Base

      attr_reader :conn

      def initialize(connection)
        @conn = connection
      end

      def <<(data)
        self.class::FRAME_CLASS.parse_all(data).each do |frame|
          recv_frame frame
        end
      end

      def ping(data)
        raise "#{self.class.name}\#ping is abstract"
      end

      def close
        raise "#{self.class.name}\#close is abstract"
      end

      def self.handshake(request, response)
        raise "#{self.class.name}::handshake is abstract"
      end

      def send_message(message)
        self.class::FRAME_CLASS.for_message(message).each do |frame|
          @conn.send_data frame.to_s
        end
      end

      protected

      def recv_frame(frame)
        raise "#{self.class.name}\#handle_frame is abstract"
      end

    end

  end
end