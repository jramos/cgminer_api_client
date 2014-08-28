module CgminerApiClient
  module SocketWithTimeout
    def open_socket(host, port, timeout)
      addr     = Socket.getaddrinfo(host, nil)
      sockaddr = Socket.pack_sockaddr_in(port, addr[0][3])

      Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0).tap do |socket|
        socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

        begin
          socket.connect_nonblock(sockaddr)
        rescue IO::WaitWritable
          if IO.select(nil, [socket], nil, timeout)
            begin
              socket.connect_nonblock(sockaddr)
            rescue Errno::EISCONN
              # the socket is connected
            rescue
              socket.close
              raise
            end
          else
            socket.close
            raise "Connection timeout"
          end
        end
      end
    end
  end
end