require 'delegate'

module LibWebSockets

  class SocketWrapper < SimpleDelegator

    attr_accessor :blocking
    attr_reader :socket
    alias_method :to_io, :socket

    def initialize(socket, conn_class, blocking, &on_message)
      @socket = socket
      @conn = conn_class.new &method(:data_sender)
      super(@conn)
      @conn.on_close &method(:close!)
      @conn.on_message &on_message
    end

    def on_close(&block)
      @on_close = block
    end

    # must override SimpleDelegator::send
    def send(message)
      @conn.send message
    end

    def recv
      data = @socket.__send__(@blocking ? :recvmsg : :recvmsg_nonblock)[0]
      if data.empty?
        close!
      else
        @conn.recv data
      end
    end

    def connection
      @conn
    end

    private

    def close!
      @socket.close
      @on_close.call if @on_close
    end

    def data_sender(data)
      @socket.__send__ @blocking ? :sendmsg : :sendmsg_nonblock, data
    end

  end

end