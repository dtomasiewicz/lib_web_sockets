module LibWebSockets

  # supported versions of the WebSocket standard.
  # if running a server and multiple versions are supported by the client,
  # the first one in this Array will be selected
  VERSIONS = ['13']

end

require 'lib_web_sockets/connection'
require 'lib_web_sockets/client_connection'
require 'lib_web_sockets/server_connection'
require 'lib_web_sockets/frame'
require 'lib_web_sockets/http'
require 'lib_web_sockets/socket_wrapper'