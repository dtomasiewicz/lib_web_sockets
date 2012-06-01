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

    # abstract handshake_recv

    # Connection exceptions
    class NotOpen < IOError; end
    class NoData < IOError; end
    class InvalidMessage < IOError; end
    class InvalidData < IOError; end
    class NoDataSender < IOError; end

    attr_reader :state
    attr_accessor :data_sender

    def initialize(&data_sender)
      @state = :opening
      @data_sender = data_sender
      @handler = nil
      @pong_callback = nil
    end

    # Wraps a raw Socket object in a SocketWrapper, which exposes a similar
    # interface to Connection but uses the Socket object for I/O. If blocking
    # is a false value (default), the *_nonblock versions of socket methods
    # will be used. If a block is passed, it will be registered as the
    # on_message handler (see Connection#on_message).
    def self.wrap(socket, blocking = false, &on_message)
      SocketWrapper.new socket, self, blocking, &on_message
    end

    # Process data received by the connection's I/O source.
    def recv(data)
      raise InvalidData, 'expecting String' unless data.kind_of? String
      raise NoData if data.bytesize == 0

      case @state
      when :open, :closing
        @handler << data
      when :opening
        handshake_recv data
      when :closed
        # discard
      end
    end

    # Send a WebSocket message. The message type will be determined by the
    # encoding of the _message_ string. The registered data_sender block will
    # be invoked to send raw data.
    def send(message)
      raise InvalidMessage, 'not a String' unless message.kind_of? String
      raise NotOpen, to_s unless state? :open

      @handler.send_message message
    end

    # Ping the remote host, invoking the (optional) _pong_callback_ when a Pong
    # response is received. A _payload_ string may be supplied, but it will be 
    # sent as-is (NOT encoded to UTF-8) regardless of its encoding.
    #
    # Only one _pong_callback_ may be registered at a time, and sending another
    # Ping before a Pong is received will result in the existing callbacks being
    # unregistered (even if no new callback is supplied).
    def ping(payload = nil, &pong_callback)
      @handler.ping payload
      @pong_callback = pong_callback
    end

    def close
      raise InvalidState, 'connection is not open' unless state? [:opening, :open]
      @handler.close
    end

    # Register a block to be called once the connection reaches the :open
    # state.
    def on_open(&block)
      @on_open = block
    end

    # Register a block to be called once the connection reaches the :closed
    # state.
    def on_close(&block)
      @on_close = block
    end

    # Register a block handler to be called once an entire message is received.
    # The block will be passed a single argument-- the received message as a
    # string, encoded based on the message type.
    #
    # Message frames will NOT be buffered if an on_message_frame block is
    # registered without an on_message block. This could be a problem if an
    # on_message_frame handler is registered, THEN the first frame(s) of a
    # fragmented message is received, THEN an on_message handler is registered.
    def on_message(&block)
      @on_message = block
    end


    # Register a block handler to be called once an entire message is received.
    # The block will be passed a single argument-- an instance of a Frame sub-
    # class dependent on the protocol version in use.
    #
    # Message frames will NOT be buffered if an on_message_frame block is
    # registered without an on_message block. This could be a problem if an
    # on_message_frame handler is registered, THEN the first frame(s) of a
    # fragmented message is received, THEN an on_message handler is registered.
    def on_message_frame(&block)
      @on_message_frame = block
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

    def buffer_message?
      @on_message || !@on_message_frame
    end

    def send_data(data)
      raise InvalidState, @state.to_s unless state? [:opening, :open]

      if @data_sender
        @data_sender.call data
      else
        raise NoDataSender, to_s
      end
    end

    def open!
      @state = :open
      @on_open.call if @on_open
    end

    def closing!
      raise InvalidState, 'cannot close a non-open connection' unless open?
      @state = :closing
    end

    def closed!
      @state = :closed
      @on_close.call if @on_close
    end

    def message_frame!(frame)
      @on_message_frame.call frame if @on_message_frame
    end

    def message!(message)
      @on_message.call message if @on_message
    end

    def pong!
      if handler = @pong_callback
        @pong_callback = nil
        handler.call
      end
    end

    protected

    attr_accessor :handler

  end

end