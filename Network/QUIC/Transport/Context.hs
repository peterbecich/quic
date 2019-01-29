module Network.QUIC.Transport.Context where

import Data.IORef
-- import Data.ByteString
import qualified Network.TLS as TLS

import Network.QUIC.TLS
import Network.QUIC.Transport.Types

data Role = Client TLS.ClientParams
          | Server TLS.ServerParams

data Context = Context {
    role :: Role
  , tlsConetxt        :: TLS.Context
  , connectionID      :: CID -- fixme
  , initialSecret     :: (Secret, Secret)
  , usedCipher        :: IORef Cipher
  , earlySecret       :: IORef (Maybe TLS.SecretTriple)
  , handshakeSecret   :: IORef (Maybe TLS.SecretTriple)
  , applicationSecret :: IORef (Maybe TLS.SecretTriple)
  -- intentionally using the single space for packet numbers.
  , packetNumber      :: IORef PacketNumber
  }

clientContext :: TLS.HostName -> CID -> IO Context
clientContext hostname cid = do
    (tlsctx, cparams) <- tlsClientContext hostname
    let cis = clientInitialSecret cid
        sis = serverInitialSecret cid
    Context (Client cparams) tlsctx cid (cis, sis) <$> newIORef defaultCipher <*> newIORef Nothing <*> newIORef Nothing <*> newIORef Nothing <*> newIORef 0

serverContext :: FilePath -> FilePath -> CID -> IO Context
serverContext key cert cid = do
    (tlsctx, sparams) <- tlsServerContext key cert
    let cis = clientInitialSecret cid
        sis = serverInitialSecret cid
    Context (Server sparams) tlsctx cid (cis, sis) <$> newIORef defaultCipher <*> newIORef Nothing <*> newIORef Nothing <*> newIORef Nothing <*> newIORef 0

tlsClientParams :: Context -> TLS.ClientParams
tlsClientParams ctx = case role ctx of
  Client cparams -> cparams
  Server _       -> error "tlsClientParams"

tlsServerParams :: Context -> TLS.ServerParams
tlsServerParams ctx = case role ctx of
  Server sparams -> sparams
  Client _       -> error "tlsServerParams"

getCipher :: Context -> IO Cipher
getCipher ctx = readIORef (usedCipher ctx)

setCipher :: Context -> Cipher -> IO ()
setCipher ctx cipher = writeIORef (usedCipher ctx) cipher
