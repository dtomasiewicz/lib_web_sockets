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

    # abstract opening_recv_data

    # Connection exceptions
    class NotOpen < IOError; end
    class NoData < IOError; end
    class InvalidMessage < IOError; end
    class InvalidData < IOError; end
    class NoDataSender < IOError; end
    class BadFrameOp < IOError; end
    class BadFrameSequence < IOError; end

    attr_reader :state
    attr_accessor :data_sender

    def initialize(&data_sender)
      @state = :opening
      @data_sender = data_sender
      @pong_handlers = []
    end

    def self.wrap(socket, blocking = false, &on_message)
      SocketWrapper.new socket, self, blocking, &on_message
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

      op = message.encoding == Frame::BINARY_ENCODING ? :binary : :text

      Frame.for_message(op, message).each do |frame|
        send_data frame.to_s
      end
    end

    def ping(data = nil, &pong_handler)
      @pong_handlers << pong_handler
      send_data Frame.new(:ping, data).to_s
    end

    def close
      raise InvalidState, 'connection is not open' unless state? [:opening, :open]
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
      Frame.parse_all(data).each do |frame|
        case frame.op
        when :continue, :text, :binary
          if frame.continue?
            raise BadFrameSequence, 'unexpected continuation frame' unless @message
            @message << frame
          else
            @message = [frame]
          end

          if frame.fin?
            message! Frame.join(@message)
            @message = nil
          end
        when :close
          send_close_frame if open?
          closed!
        when :ping
          send_data Frame.new(:pong, frame.payload).to_s
        when :pong
          if handler = @pong_handlers.shift
            handler.call
          end
        else
          raise BadFrameOp, "unsupported/unimplemented frame op: #{frame.op}"
        end
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