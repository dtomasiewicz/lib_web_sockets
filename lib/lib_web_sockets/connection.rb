module LibWebSockets

  class Connection

    class NoDataSender < IOError; end
    class InvalidState < IOError; end
    class InvalidMessage < IOError; end
    class InvalidData < IOError; end
    class Failed < IOError; end

    attr_reader :socket
    alias_method :to_io, :socket
    attr_accessor :blocking

    # Initialize a new Connection object. If blocking is a false value 
    # (default), the *_nonblock versions of socket methods will be used.
    # If a block is passed, it will be registered as the on_message handler
    # (see Connection#on_message=).
    def initialize(socket, blocking = false, &on_message)
      @socket = socket
      @blocking = blocking
      @on_message = on_message
      @state = :connecting
    end

    def recv
      begin
        data = @socket.__send__(@blocking ? :recvmsg : :recvmsg_nonblock)[0]
        raise Failed, 'no data on socket' if data.bytesize == 0
        recv_data data
      rescue Failed
        closed!
      end
    end

    # Getter for the _on_open_ handler. If a block is supplied, it will be set
    # as the new _on_open_ handler (see Connection#on_open=).
    def on_open(&block)
      @on_open = block if block
      @on_open
    end

    # Register a block handler to be called once the connection has been 
    # opened.
    attr_writer :on_open

    # Getter for the _on_close_ handler. If a block is supplied, it will be set
    # as the new _on_close_ handler (see Connection#on_close=).
    def on_close(&block)
      @on_close = block if block
      @on_close
    end

    # Register a block handler to be called once the connection has been 
    # closed.
    attr_writer :on_close

    # Getter for the _on_message_ handler. If a block is supplied, it will be
    # set as the new _on_message_ handler (see Connection#on_message=).
    def on_message(&block)
      @on_message = block if block
      @on_message
    end

    # Register a block handler to be called once an entire message is received.
    # The block will be passed a single argument-- the received message as a
    # string, encoded based on the message type.
    #
    # Message frames will NOT be buffered if an on_message_frame block is
    # registered without an on_message block. This could be a problem if an
    # on_message_frame handler is registered, THEN the first frame(s) of a
    # fragmented message is received, THEN an on_message handler is registered.
    attr_writer :on_message

    # Getter for the _on_message_frame_ handler. If a block is supplied, it 
    # will be set as the new _on_message_frame_ handler (see 
    # Connection#on_message_frame=).
    def on_message_frame(&block)
      @on_message_frame = block
      @on_message_frame
    end

    # Register a block handler to be called once a message frame is received.
    # The block will be passed a single argument-- an instance of a Frame sub-
    # class dependent on the protocol version in use.
    #
    # Message frames will NOT be buffered if an on_message_frame block is
    # registered without an on_message block. This could be a problem if an
    # on_message_frame handler is registered, THEN the first frame(s) of a
    # fragmented message is received, THEN an on_message handler is registered.
    attr_writer :on_message_frame

    # Returns the current connection state (a symbol).
    attr_reader :state

    # Determine whether the connection is in the given state(s). Returns a true
    # value only if _test_ (or any of its elements) matches the current 
    # connection state.
    #
    # If _test_ is NOT an Enumerable, it will be converted to a symbol and 
    # checked againstthe current state. If _test_ IS an Enumerable, each of its
    # elements will be converted to a symbol and tested against the current 
    # state. 
    def state?(test)
      if test.respond_to? :include?
        test.map(&:to_sym).include? @state
      else
        @state == test.to_sym
      end
    end

    # Returns a true value only if the connection is in the :connecting state.
    def connecting?; @state == :connecting; end
    # Returns a true value only if the connection is in the :open state.
    def open?; @state == :open; end
    # Returns a true value only if the connection is in the :closing state.
    def closing?; @state == :closing; end
    # Returns a true value only if the connection is in the :closed state.
    def closed?; @state == :closed; end

    # Returns a true value only if the connection will buffer incoming message
    # frames until a full message is receieved. Message frames will not be 
    # buffered if there is an _on_message_frame_ handler without an
    # _on_message_ handler.
    def buffer_message?
      @on_message || !@on_message_frame
    end

    private

    def send_data(data)
      @socket.__send__ @blocking ? :sendmsg : :sendmsg_nonblock, data
    end

    def open!(*args)
      @state = :open
      @on_open.call *args if @on_open
    end

    def closed!(*args)
      @socket.close
      @state = :closed
      @on_close.call *args if @on_close
    end

    def message_frame!(*args)
      @on_message_frame.call *args if @on_message_frame
    end

    def message!(*args)
      @on_message.call *args if @on_message
    end

  end

end