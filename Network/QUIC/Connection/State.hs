{-# LANGUAGE RecordWildCards #-}

module Network.QUIC.Connection.State (
    isConnectionOpen
  , setConnection0RTTReady
  , isConnection1RTTReady
  , setConnection1RTTReady
  , isConnectionEstablished
  , setConnectionEstablished
  , isCloseSent
  , setCloseSent
  , isCloseReceived
  , setCloseReceived
  , wait0RTTReady
  , wait1RTTReady
  , waitEstablished
  , waitClosed
  , addTxData
  , getTxData
  , setTxMaxData
  , getTxMaxData
  , addRxData
  , getRxData
  , addRxMaxData
  , getRxMaxData
  , getRxDataWindow
  , addTxBytes
  , getTxBytes
  , addRxBytes
  , getRxBytes
  , setAddressValidated
  , waitAntiAmplificationFree
  ) where

import Control.Concurrent.STM

import Network.QUIC.Connection.Types
import Network.QUIC.Connector
import Network.QUIC.Imports
import Network.QUIC.Recovery
import Network.QUIC.Stream

----------------------------------------------------------------

setConnectionState :: Connection -> ConnectionState -> IO ()
setConnectionState Connection{..} st =
    atomically $ writeTVar (connectionState connState) st

setConnection0RTTReady :: Connection -> IO ()
setConnection0RTTReady conn = setConnectionState conn ReadyFor0RTT

setConnection1RTTReady :: Connection -> IO ()
setConnection1RTTReady conn = do
    setConnectionState conn ReadyFor1RTT
    writeIORef (shared1RTTReady $ shared conn) True

setConnectionEstablished :: Connection -> IO ()
setConnectionEstablished conn = setConnectionState conn Established

----------------------------------------------------------------

isConnection1RTTReady :: Connection -> IO Bool
isConnection1RTTReady Connection{..} = atomically $ do
    st <- readTVar $ connectionState connState
    return (st >= ReadyFor1RTT)

----------------------------------------------------------------

setCloseSent :: Connection -> IO ()
setCloseSent Connection{..} = do
    atomically $ do
        modifyTVar closeState $ \cs -> cs { closeSent = True }
        writeTVar (connectionState connState) Closing
    writeIORef (sharedCloseSent shared) True

setCloseReceived :: Connection -> IO ()
setCloseReceived Connection{..} = do
    atomically $ do
        modifyTVar closeState $ \cs -> cs { closeReceived = True }
        writeTVar (connectionState connState) Closing
    writeIORef (sharedCloseReceived shared) True

isCloseSent :: Connection -> IO Bool
isCloseSent Connection{..} =
    atomically (closeSent <$> readTVar closeState)

isCloseReceived :: Connection -> IO Bool
isCloseReceived Connection{..} =
    atomically (closeReceived <$> readTVar closeState)

wait0RTTReady :: Connection -> IO ()
wait0RTTReady Connection{..} = atomically $ do
    cs <- readTVar $ connectionState connState
    check (cs >= ReadyFor0RTT)

wait1RTTReady :: Connection -> IO ()
wait1RTTReady Connection{..} = atomically $ do
    cs <- readTVar $ connectionState connState
    check (cs >= ReadyFor1RTT)

waitEstablished :: Connection -> IO ()
waitEstablished Connection{..} = atomically $ do
    cs <- readTVar $ connectionState connState
    check (cs >= Established)

waitClosed :: Connection -> IO ()
waitClosed Connection{..} = atomically $ do
    cs <- readTVar closeState
    check (cs == CloseState True True)

----------------------------------------------------------------

addTxData :: Connection -> Int -> IO ()
addTxData Connection{..} n = atomically $ modifyTVar' flowTx add
  where
    add flow = flow { flowData = flowData flow + n }

getTxData :: Connection -> IO Int
getTxData Connection{..} = atomically $ flowData <$> readTVar flowTx

setTxMaxData :: Connection -> Int -> IO ()
setTxMaxData Connection{..} n = atomically $ modifyTVar' flowTx set
  where
    set flow
      | flowMaxData flow < n = flow { flowMaxData = n }
      | otherwise            = flow

getTxMaxData :: Connection -> STM Int
getTxMaxData Connection{..} = flowMaxData <$> readTVar flowTx

----------------------------------------------------------------

addRxData :: Connection -> Int -> IO ()
addRxData Connection{..} n = atomicModifyIORef'' flowRx add
  where
    add flow = flow { flowData = flowData flow + n }

getRxData :: Connection -> IO Int
getRxData Connection{..} = flowData <$> readIORef flowRx

addRxMaxData :: Connection -> Int -> IO Int
addRxMaxData Connection{..} n = atomicModifyIORef' flowRx add
  where
    add flow = (flow { flowMaxData = m }, m)
      where
        m = flowMaxData flow + n

getRxMaxData :: Connection -> IO Int
getRxMaxData Connection{..} = flowMaxData <$> readIORef flowRx

getRxDataWindow :: Connection -> IO Int
getRxDataWindow Connection{..} = flowWindow <$> readIORef flowRx

----------------------------------------------------------------

addTxBytes :: Connection -> Int -> IO ()
addTxBytes Connection{..} n = atomically $ modifyTVar' bytesTx (+ n)

getTxBytes :: Connection -> IO Int
getTxBytes Connection{..} = readTVarIO bytesTx

addRxBytes :: Connection -> Int -> IO ()
addRxBytes Connection{..} n = atomically $ modifyTVar' bytesRx (+ n)

getRxBytes :: Connection -> IO Int
getRxBytes Connection{..} = readTVarIO bytesRx

----------------------------------------------------------------

setAddressValidated :: Connection -> IO ()
setAddressValidated Connection{..} = atomically $ writeTVar addressValidated True

waitAntiAmplificationFree :: Connection -> Int -> IO ()
waitAntiAmplificationFree Connection{..} siz = do
    ok <- atomically cond
    unless ok $ do
        beforeAntiAmp connLDCC
        atomically (cond >>= check)
        -- setLossDetectionTimer is called eventually.
  where
    cond = do
        validated <- readTVar addressValidated
        if validated then
            return True
          else do
            tx <- readTVar bytesTx
            rx <- readTVar bytesRx
            return (tx + siz <= 3 * rx)
