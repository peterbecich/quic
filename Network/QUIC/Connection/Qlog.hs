{-# LANGUAGE RecordWildCards #-}

module Network.QUIC.Connection.Qlog where

import Network.QUIC.Connection.Types
import Network.QUIC.Qlog
import Network.QUIC.Types

qlogReceived :: Qlog a => Connection -> a -> IO ()
qlogReceived Connection{..} pkt = connQLog $ QReceived $ qlog pkt

qlogSent :: Qlog a => Connection -> a -> IO ()
qlogSent Connection{..} pkt = connQLog $ QSent $ qlog pkt

qlogDropped :: Qlog a => Connection -> a -> IO ()
qlogDropped Connection{..} pkt = connQLog $ QDropped $ qlog pkt

qlogPrologue :: Connection -> String -> CID -> IO ()
qlogPrologue Connection{..} rol cid = connQLog $ QProlog rol cid

qlogEpilogue :: Connection -> IO ()
qlogEpilogue Connection{..} = connQLog QEpilogue

qlogRecvInitial :: Connection -> IO ()
qlogRecvInitial Connection{..} = connQLog QRecvInitial

qlogSentRetry :: Connection -> IO ()
qlogSentRetry Connection{..} = connQLog QSentRetry
