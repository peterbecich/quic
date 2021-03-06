{-# LANGUAGE OverloadedStrings #-}

module Network.QUIC.Stream.Table (
    StreamTable
  , emptyStreamTable
  , lookupStream
  , insertStream
  , deleteStream
  , insertCryptoStreams
  , deleteCryptoStream
  , lookupCryptoStream
  ) where

import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as Map

import Network.QUIC.Stream.Types
import Network.QUIC.Types

----------------------------------------------------------------

newtype StreamTable = StreamTable (IntMap Stream)

emptyStreamTable :: StreamTable
emptyStreamTable = StreamTable Map.empty

----------------------------------------------------------------

lookupStream :: StreamId -> StreamTable -> Maybe Stream
lookupStream sid (StreamTable tbl) = Map.lookup sid tbl

insertStream :: StreamId -> Stream -> StreamTable -> StreamTable
insertStream sid strm (StreamTable tbl) = StreamTable $ Map.insert sid strm tbl

deleteStream :: StreamId -> StreamTable -> StreamTable
deleteStream sid (StreamTable tbl) = StreamTable $ Map.delete sid tbl

----------------------------------------------------------------

initialCryptoStreamId,handshakeCryptoStreamId,rtt1CryptoStreamId :: StreamId
initialCryptoStreamId   = -1
handshakeCryptoStreamId = -2
rtt1CryptoStreamId      = -3

toCryptoStreamId :: EncryptionLevel -> StreamId
toCryptoStreamId InitialLevel   = initialCryptoStreamId
toCryptoStreamId RTT0Level      = error "toCryptoStreamId"
toCryptoStreamId HandshakeLevel = handshakeCryptoStreamId
toCryptoStreamId RTT1Level      = rtt1CryptoStreamId

----------------------------------------------------------------

insertCryptoStreams :: StreamTable -> Shared -> IO StreamTable
insertCryptoStreams stbl shrd = do
    strm1 <- newStream initialCryptoStreamId   shrd
    strm2 <- newStream handshakeCryptoStreamId shrd
    strm3 <- newStream rtt1CryptoStreamId      shrd
    return $ insertStream initialCryptoStreamId   strm1
           $ insertStream handshakeCryptoStreamId strm2
           $ insertStream rtt1CryptoStreamId      strm3 stbl

deleteCryptoStream :: EncryptionLevel -> StreamTable -> StreamTable
deleteCryptoStream InitialLevel   = deleteStream initialCryptoStreamId
deleteCryptoStream RTT0Level      = error "deleteCryptoStream"
deleteCryptoStream HandshakeLevel = deleteStream handshakeCryptoStreamId
deleteCryptoStream RTT1Level      = deleteStream rtt1CryptoStreamId

----------------------------------------------------------------

lookupCryptoStream :: EncryptionLevel -> StreamTable -> Stream
lookupCryptoStream lvl stbl = strm
  where
    sid = toCryptoStreamId lvl
    Just strm = lookupStream sid stbl
