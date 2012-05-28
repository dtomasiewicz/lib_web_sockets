module LibWebSockets

  class Frame

    class InvalidPayload < StandardError; end
    class InvalidFrameSize < StandardError; end

    MAX_UINT64 = 18446744073709551615
    MAX_UINT16 = 65535

    OPS = [
      :continue, # 0x0
      :text,     # 0x1
      :binary,   # 0x2
      :reserved, # 0x3
      :reserved, # 0x4
      :reserved, # 0x5
      :reserved, # 0x6
      :reserved, # 0x7
      :close,    # 0x8
      :ping,     # 0x9
      :pong,     # 0xA
      :reserved, # 0xB
      :reserved, # 0xC
      :reserved, # 0xD
      :reserved, # 0xE
      :reserved, # 0xF
    ]

    attr_accessor :op, :payload, :extra

    def initialize(op, payload = nil, fin = false, extra = {})
      @op, @payload, @fin, @extra = op, payload.dup, fin, extra.dup
    end

    def fin?
      @fin
    end

    # parses an individual Frame as per section 5.2
    # unpack codes:
    #   n   uint16 network-endian
    #   N   uint32 network-endian
    #   Q>  uint64 big-endian (= network-endian)
    # returns Frame, remaining_data
    def self.parse(data)
      i = 0 # number of bytes read/parsed so far
      extra = {} # uncommon fields

      # FIN, RSV1, RSV2, RSV3, opcode(4), MASK, Payload len(7)
      intro = data[i, 2].unpack('n')[0]
      i += 2

      fin = intro & 1 > 0
      extra[:rsv1] = intro & 2 > 0
      extra[:rsv2] = intro & 4 > 0
      extra[:rsv3] = intro & 8 > 0
      op = OPS[intro >> 4 & 15]
      mask = intro & 256 > 0
      payload_len = intro >> 9 & 127

      if payload_len > 125
        if payload_len == 126
          # 16-bit Extended payload len
          payload_len = data[i, 2].unpack('n')[0]
          i += 2
        else
          # 64-bit Extended payload len
          payload_len = data[i, 8].unpack('Q>')[0]
          i += 8
        end
      end

      if mask
        extra[:masking_key] = data[i, 4].unpack('N')[0]
        i += 4
      end

      payload = data[i, payload_len]
      i += payload_len

      return new(op, payload, fin, extra), data[i..-1]
    end

    # parses the given chunk of data into one or more Frames
    def self.parse_all(data)
      frames = []
      while data.length > 0
        frame, data = parse data
        frames << frame
      end
      frames
    end

    def to_s
      data, format = [], ''

      intro = @fin ? 1 : 0
      intro |= 2 if @extra[:rsv1]
      intro |= 4 if @extra[:rsv2]
      intro |= 8 if @extra[:rsv3]
      intro |= OPS.index(@op) << 4
      intro |= 256 if @extra[:masking_key]
    
      epl = nil
      if @payload
        payload_len = @payload.length
        if payload_len > MAX_UINT64
          raise InvalidPayload, "#{@payload.length} (require 0..#{MAX_UINT64})"
        elsif payload_len > MAX_UINT16
          epl, payload_len = payload_len, 127
          epl_format = 'Q>'
        elsif payload_len > 125
          epl, payload_len = payload_len, 126
          epl_format = 'n'
        end
      else
        payload_len = 0
      end

      intro |= payload_len << 9
      data << intro
      format << 'n'

      if epl
        data << epl
        format << epl_format
      end

      if @extra[:masking_key]
        data << @extra[:masking_key]
        format << 'N'
      end

      if @payload
        data << @payload
        format << "A#{@payload.length}"
      end

      data.pack format
    end

    # generate a frame sequence from the given message
    # type is :text or :binary
    # message is a binary string.
    # frame_size is the maximum byte size for each individual frame.
    #   must be in [1, MAX_UINT64]
    def self.for_message(type, message, frame_size = MAX_UINT64)
      raise InvalidFrameSize unless (1..MAX_UINT64).include? frame_size

      framed = 0 # length of already framed portion
      frames = []
      while framed < message.length
        op = frames.length == 0 ? type : :continue
        payload = message.length-framed > frame_size ?
          message[framed, frame_size] :
          message[framed..-1]
        framed += payload.length
        frames << new(op, payload, message.length == framed)
      end
      frames
    end

    def op?(test)
      if test.kind_of? Array
        test.map(&:to_sym).include? @op
      else
        @op == test.to_sym
      end
    end

    def continue?; type? :continue; end
    def text?; type? :text; end
    def binary?; type? :binary; end
    def close?; type? :close; end
    def ping?; type? :ping; end
    def pong?; type? :pong; end

  end

end