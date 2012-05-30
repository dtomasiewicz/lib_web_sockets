module LibWebSockets

  class SocketWrapper

    attr_accessor :blocking
    attr_reader :socket
    alias_method :to_io, :socket

    def initialize(socket, conn_class, blocking, &on_message)
      @socket = socket
      @conn = conn_class.new &method(:data_sender)
      @conn.on_close &method(:close!)
      @conn.on_message &on_message
    end

    def on_close(&block)
      @on_close = block
    end

    def recv_data
      @conn.recv_data @socket.__send__(@blocking ? :recvmsg : :recvmsg_nonblock)[0]
    end

    def connection
      @conn
    end

    private

    # delegate all other calls to the Connection object
    def method_missing(method, *args, &block)
      @conn.send method, *args, &block
    end

    def close!
      @socket.close
      @on_close.call if @on_close
    end

    def data_sender(data)
      @socket.__send__ @blocking ? :sendmsg : :sendmsg_nonblock, data
    end

  end

end