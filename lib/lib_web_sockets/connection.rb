module LibWebSockets

  class Connection

    # State Transitions
    # client
    #   :opening to :open after OHS response receieved
    # server
    #   :opening to :open after OHS response sent
    # all
    #   send closing sequence:
    #     :open to :closing after sent
    #     :closing to :closed after sequence received
    #   receive closing sequence:
    #     :open to :closed after return sequence sent
    #     (effectively :open to :closed)

    # abstract opening_recv_data

    # Connection exceptions
    class NotOpen < IOError; end
    class NoData < IOError; end
    class InvalidMessage < IOError; end
    class InvalidData < IOError; end
    class NoDataSender < IOError; end
    class BadFrameOp < IOError; end
    class BadFrameSequence < IOError; end

    TEXT_ENCODING = 'UTF-8'
    BINARY_ENCODING = 'ASCII-8BIT'

    attr_reader :state
    attr_accessor :data_sender

    def initialize(&data_sender)
      @state = :opening
      @data_sender = data_sender
    end

    def self.[](socket, blocking = false)
      SocketWrapper.new socket, self, blocking
    end

    def recv_data(data)
      raise InvalidData, 'expecting String' unless data.is_a? String
      raise NoData if data.bytesize == 0

      case @state
      when :open, :closing
        self << data
      when :opening
        opening_recv_data data
      when :closed
        # discard per section 1.4
      end
    end

    def send_message(message)
      raise InvalidMessage, 'not a String' unless message.is_a? String
      raise NotOpen, to_s unless state? :open

      if message.encoding.name == BINARY_ENCODING
        type = :binary
      else
        type = :text
        message = encode_text message # original encoding to TEXT_ENCODING
        message = force_binary message # BINARY_ENCODING for slicing
      end

      Frame.for_message(type, message).each do |frame|
        send_data frame.to_s
      end
    end

    def close
      send_close_frame
      @state = :closing
    end

    def on_message(&block)
      @on_message = block
    end

    def on_open(&block)
      @on_open = block
    end

    def on_close(&block)
      @on_close = block
    end

    def state?(test)
      if test.kind_of? Array
        test.map(&:to_sym).include? @state
      else
        @state == test.to_sym
      end
    end

    def opening?; state? :opening; end
    def open?; state? :open; end
    def closing?; state? :closing; end
    def closed?; state? :closed; end

    protected

    def <<(data)
      data = force_binary data
      Frame.parse_all(data).each do |frame|
        case frame.op
        when :continue
          raise BadFrameSequence, 'unexpected continuation frame' unless @message
          @message << frame
        when :text, :binary
          @message = [frame]
        when :close
          send_close_frame if open?
          closed!
        else
          raise BadFrameOp, "unsupported/unimplemented frame op: #{frame.op}"
        end

        if @message && frame.fin?
          msg = @message.map(&:payload).join
          msg = force_text(msg) if @message.first.text?
          message! msg
          @message = nil
        end
      end
    end

    def force_text(data)
      return data if data.encoding.name == TEXT_ENCODING
      data = data.dup.force_encoding TEXT_ENCODING
      raise InvalidData, "data is not valid #{TEXT_ENCODING}" unless data.valid_encoding?
      return data
    end

    def force_binary(data)
      return data if data.encoding.name == BINARY_ENCODING
      data.dup.force_encoding BINARY_ENCODING
    end

    def encode_text(data)
      return data if data.encoding.name == TEXT_ENCODING
      begin
        return data.encode TEXT_ENCODING
      rescue Encoding::InvalidByteSequenceError
        raise InvalidData, "data is not encodable as #{TEXT_ENCODING}"
      end
    end

    # per section 1.4, messages can only be sent in the :open state
    # data can be sent internally in the :opening state
    def send_data(data)
      raise InvalidState, @state.to_s unless state? [:opening, :open]

      if @data_sender
        @data_sender.call data
      else
        raise NoDataSender, to_s
      end
    end

    def send_close_frame
      send_data Frame.new(:close).to_s
    end

    def open!
      @state = :open
      @frames = []
      @on_open.call if @on_open
    end

    def closed!
      @state = :closed
      @on_close.call if @on_close
    end

    def message!(message)
      @on_message.call message if @on_message
    end

    def state=(state)
      @state = state
    end

  end

end