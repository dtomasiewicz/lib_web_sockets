module LibWebSockets
  module Frame

    class Frame13 < Base

      OPS = [
        :continuation, # 0x0
        :text,         # 0x1
        :binary,       # 0x2
        :rsv_nc_1,     # 0x3
        :rsv_nc_2,     # 0x4
        :rsv_nc_3,     # 0x5
        :rsv_nc_4,     # 0x6
        :rsv_nc_5,     # 0x7
        :close,        # 0x8
        :ping,         # 0x9
        :pong,         # 0xA
        :rsv_c_1,      # 0xB
        :rsv_c_2,      # 0xC
        :rsv_c_3,      # 0xD
        :rsv_c_4,      # 0xE
        :rsv_c_5,      # 0xF
      ]

      MAX_UINT64 = 18446744073709551615
      MAX_UINT16 = 65535

      attr_accessor :rsv1, :rsv2, :rsv3, :masking_key
      alias_method :masked?, :masking_key

      def initialize(op, payload = "", fin = true, extra = {})
        super(op, payload, fin)
        @rsv1 = extra[:rsv1]
        @rsv2 = extra[:rsv2]
        @rsv3 = extra[:rsv3]
        @masking_key = extra[:masking_key].dup if extra[:masking_key]
      end

      # parses an individual Frame as per section 5.2
      # returns Frame, remaining_data
      def self.parse(data)
        i = 0 # number of bytes read/parsed so far
        extra = {}

        # FIN, RSV1, RSV2, RSV3, opcode(4)
        b1 = byteslice(data, i, 1).unpack('C')[0]
        i += 1
        fin = b1 & 128 > 0
        extra[:rsv1] = b1 & 64 > 0
        extra[:rsv2] = b1 & 32 > 0
        extra[:rsv3] = b1 & 16 > 0
        op = OPS[b1 & 15]

        # MASKED, Payload len(7)
        b2 = byteslice(data, i, 1).unpack('C')[0]
        i += 1
        masked = b2 & 128 > 0
        payload_len = b2 & 127

        if payload_len > 125
          if payload_len == 126
            # 16-bit Extended payload len
            payload_len = byteslice(data, i, 2).unpack('n')[0]
            i += 2
          else
            # 64-bit Extended payload len
            payload_len = byteslice(data, i, 8).unpack('Q>')[0]
            i += 8
          end
        end

        if masked
          extra[:masking_key] = byteslice(data, i, 4).unpack('A4')[0]
          i += 4
        end

        payload = byteslice(data, i, payload_len)
        mask! payload, extra[:masking_key] if masked
        i += payload_len

        return new(op, payload, fin, extra), byteslice(data, i)
      end

      def to_s
        data, format = [], ''

        b1 = self.fin ? 128 : 0
        b1 |= 64 if @rsv1
        b1 |= 32 if @rsv2
        b1 |= 16 if @rsv3
        b1 |= OPS.index @op
        data << b1
        format << 'C'

        b2 = @masking_key ? 128 : 0    
        epl = nil
        payload_len = self.payload.bytesize
        if payload_len > MAX_UINT64
          raise InvalidPayload, "#{payload.length} (require 0..#{MAX_UINT64})"
        elsif payload_len > MAX_UINT16
          epl, payload_len = payload_len, 127
          epl_format = 'Q>'
        elsif payload_len > 125
          epl, payload_len = payload_len, 126
          epl_format = 'n'
        end
        b2 |= payload_len

        data << b2
        format << 'C'

        if epl
          data << epl
          format << epl_format
        end

        if @masking_key
          data << @masking_key
          format << 'A4'
        end

        if payload_len > 0
          data << (@masking_key ? self.class.mask(self.payload, @masking_key) : self.payload)
          format << "A#{self.payload.bytesize}"
        end

        data.pack format
      end

      # generate a frame sequence from the given message
      # type is :text or :binary
      # message is a binary string.
      # frame_size is the maximum byte size for each individual frame.
      #   must be in [1, MAX_UINT64]
      def self.for_message(message, frame_size = MAX_UINT64)
        raise InvalidFrameSize unless (1..MAX_UINT64).include? frame_size

        if message.encoding == BINARY_ENCODING
          type = :binary
        else
          type = :text
          if message.encoding != TEXT_ENCODING
            unless message.valid_encoding?
              raise InvalidMessage, 'source message is not encoded correctly' 
            end

            begin
              message = message.encode TEXT_ENCODING
            rescue EncodingError
              raise InvalidMessage, "message cannot be encoded to #{TEXT_ENCODING}"
            end
          end
        end

        framed = 0 # length of already framed portion
        frames = []

        while framed < message.bytesize
          op = frames.length == 0 ? type : :continuation
          payload = message.bytesize-framed > frame_size ?
            byteslice(message, framed, frame_size) :
            byteslice(message, framed)
          framed += payload.length
          frames << new(op, payload, message.bytesize == framed)
        end

        frames
      end

      def op?(test)
        if test.respond_to? :include?
          test.map(&:to_sym).include? @op
        else
          @op == test.to_sym
        end
      end
      
      def continuation?; @op == :continuation; end
      def close?; @op == :close; end
      def ping?; @op == :ping; end
      def pong?; @op == :pong; end

      private

      def self.mask!(data, key)
        (0...data.length).each do |i|
          # must use setbyte; []= sometimes change the encoding
          data.setbyte i, data.getbyte(i) ^ key.getbyte(i%4)
        end
        data
      end

      def self.mask(data, key)
        mask! data.dup, key
      end

    end

  end
end