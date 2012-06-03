module LibWebSockets

  module Handler

    class FailedHandshake < StandardError; end
    class BadFrameOp < IOError; end
    class BadFrameSequence < IOError; end

  end

end

require 'lib_web_sockets/handler/server13'