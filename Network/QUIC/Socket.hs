module Network.QUIC.Socket where

import qualified Control.Exception as E
import Data.IP hiding (addr)
import Network.Socket

sockAddrFamily :: SockAddr -> Family
sockAddrFamily SockAddrInet{}  = AF_INET
sockAddrFamily SockAddrInet6{} = AF_INET6
sockAddrFamily _               = error "sockAddrFamily"

anySockAddr :: SockAddr -> SockAddr
anySockAddr (SockAddrInet p _)      = SockAddrInet  p 0
anySockAddr (SockAddrInet6 p f _ s) = SockAddrInet6 p f (0,0,0,0) s
anySockAddr _                       = error "anySockAddr"

udpServerListenSocket :: (IP, PortNumber) -> IO (Socket, SockAddr)
udpServerListenSocket ip = E.bracketOnError open close $ \s -> do
    setSocketOption s ReuseAddr 1
    withFdSocket s setCloseOnExecIfNeeded
    -- setSocketOption s IPv6Only 1 -- fixme
    bind s sa
    return (s,sa)
  where
    sa     = toSockAddr ip
    family = sockAddrFamily sa
    open   = socket family Datagram defaultProtocol

udpServerConnectedSocket :: SockAddr -> SockAddr -> IO Socket
udpServerConnectedSocket mysa peersa = E.bracketOnError open close $ \s -> do
    setSocketOption s ReuseAddr 1
    withFdSocket s setCloseOnExecIfNeeded
    bind s anysa      -- (UDP, *:13443, *:*)
    connect s peersa  -- (UDP, 127.0.0.1:13443, pa:pp)
    return s
  where
    anysa  = anySockAddr mysa
    family = sockAddrFamily mysa
    open   = socket family Datagram defaultProtocol

udpClientConnectedSocket :: HostName -> ServiceName -> IO (Socket,SockAddr)
udpClientConnectedSocket host port = do
    addr <- head <$> getAddrInfo (Just hints) (Just host) (Just port)
    E.bracketOnError (openSocket addr) close $ \s -> do
        let sa = addrAddress addr
        connect s sa
        return (s,sa)
 where
    hints = defaultHints { addrSocketType = Datagram }

udpNATRebindingSocket :: SockAddr -> IO Socket
udpNATRebindingSocket peersa = E.bracketOnError open close $ \s -> do
    connect s peersa
    return s
  where
    family = sockAddrFamily peersa
    open = socket family Datagram defaultProtocol
