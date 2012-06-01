module LibWebSockets

  module Handler

    class InvalidHandshake < StandardError; end
    class BadFrameOp < IOError; end
    class BadFrameSequence < IOError; end

  end

end

require 'lib_web_sockets/handler/base'
require 'lib_web_sockets/handler/server13'