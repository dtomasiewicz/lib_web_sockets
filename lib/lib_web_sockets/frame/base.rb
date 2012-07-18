module LibWebSockets

  module Frame

    class Base

      class InvalidPayload < StandardError; end
      class InvalidFrameSize < StandardError; end

      OPS = []
      TEXT_ENCODING = Encoding.find 'UTF-8'
      BINARY_ENCODING = Encoding.find 'ASCII-8BIT'

      attr_accessor :op, :payload, :fin
      alias_method :fin?, :fin

      def initialize(op, payload, fin)
        @op, @payload, @fin = op, payload, fin
      end

      # abstract
      def self.parse(data)
        raise "parse not implemented for #{self.name}"
      end

      # parses the given chunk of data into one or more Frames
      def self.parse_all(data)
        frames = []
        while data.bytesize > 0
          frame, data = parse data
          frames << frame
        end
        frames
      end

      def to_s
        raise "to_s not implemented for #{self.name}"
      end

      # generate a frame sequence from the given message
      def self.for_message(type, message, frame_size)
        raise "for_message not implemented for #{self.name}"
      end

      def op?(test)
        if test.kind_of? Array
          test.map(&:to_sym).include? @op
        else
          @op == test.to_sym
        end
      end
      def text?; op? :text; end
      def binary?; op? :binary; end

      # joins a list of message frames into the message's aggregate
      # payload, and encodes the resulting string based on the type of the 
      # first frame.
      def self.join(frames)
        joined = "".force_encoding self::BINARY_ENCODING
        frames.each do |frame|
          as_binary(frame.payload) {|pl| joined << pl}
        end
        joined.force_encoding self::TEXT_ENCODING if frames.first.text?
        unless joined.valid_encoding?
          raise LibWebSockets::Connection::Failed, 'invalid encoding in received message'
        end
        joined
      end

      protected

      def self.as_binary(string, &block)
        if string.encoding == self::BINARY_ENCODING
          yield string
        elsif string.frozen?
          yield string.dup.force_encoding self::BINARY_ENCODING
        else
          orig = string.encoding
          string.force_encoding self::BINARY_ENCODING
          yield string
          string.force_encoding orig
        end
      end

      # compensantes for 1.9.2's lack of String.byteslice
      def self.byteslice(string, offset, length = nil)
        length ||= string.bytesize-offset
        if string.respond_to?(:byteslice)
          string.byteslice offset, length
        else
          slice = nil
          as_binary string do
            slice = string[offset, length]
          end
          slice
        end
      end

    end

  end
end