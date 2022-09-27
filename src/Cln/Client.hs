{-# LANGUAGE
      LambdaCase
    , OverloadedStrings
    , DeriveGeneric
    , DeriveAnyClass
    , GeneralizedNewtypeDeriving
#-}

module Cln.Client where 

import Cln.Conduit
import Cln.Types
import System.IO
import System.IO.Unsafe
import GHC.IO.IOMode
import GHC.IORef
import GHC.Generics
import Data.IORef
import Data.ByteString      as S
import Data.ByteString.Lazy as L 
import Control.Monad 
import Control.Monad.State
import Control.Monad.IO.Class as O
import Data.Aeson 
import Network.Socket 
import Data.Conduit hiding (connect) 
import Data.Conduit.Combinators hiding (stdout, stderr, stdin) 
import Data.Aeson
import Data.Aeson.Types
import Data.Text

type Cln a = IO (Maybe (Fin (Res a)))

tick :: IO Value
tick = do 
    i <- readIORef idref
    writeIORef idref (i + 1) 
    pure $ toJSON i

idref :: IORef Int
idref = unsafePerformIO $ newIORef (1 :: Int) 

clnref :: IORef Handle 
clnref = unsafePerformIO $ newIORef stderr

connectCln :: String -> IO ()
connectCln d = (socket AF_UNIX Stream 0) >>= \soc -> do 
    connect soc $ SockAddrUnix d
    h <- socketToHandle soc ReadWriteMode
    writeIORef clnref h

getRes :: FromJSON a => IO (Maybe (Fin a))
getRes = (readIORef clnref) >>= \h -> runConduit $
    sourceHandle h .| 
    inConduit      .|
    await >>= pure

reqToHandle :: ToJSON a => a -> IO ()
reqToHandle a = 
    let encoded = encode a
    in do 
        L.appendFile "/home/o/Desktop/logy" $ encoded <> "\n"
        (readIORef clnref) >>= \h -> L.hPutStr h encoded 
---
newaddr :: Cln NewAddr 
newaddr = do 
    i <- tick 
    reqToHandle $ Req ("newaddr"::Text) (object []) (Just i )
    getRes

b11invoice ::  Msat -> String -> String -> Cln Invoice 
b11invoice a l d = do 
    i <- tick 
    reqToHandle $ Req ("invoice"::Text) (object [
          "amount_msat" .= a 
        , "label" .= (l <> (show i) )
        , "description" .= (d <> (show i)) ]) (Just i) 
    getRes

sendpay :: [Route] -> String -> String -> Cln SendPay 
sendpay r h v = do 
    i <- tick 
    reqToHandle $ Req ("sendpay"::Text) (object [
          "route" .= r
        , "payment_hash" .=  h
        , "payment_secret" .= v
        ]) (Just i) 
    getRes

listsendpays :: String -> Cln ListSendPays 
listsendpays h = do 
    i <- tick 
    reqToHandle $ Req ("listsendpays"::Text) (object [
        "payment_hash" .=  h ])  (Just i) 
    getRes

waitsendpay :: String -> Cln WaitSendPay 
waitsendpay h = do 
    i <- tick 
    reqToHandle $ Req ("waitsendpay"::Text) (object [
          "payment_hash" .=  h 
        , "timeout" .= (33 :: Int)  ])  (Just i) 
    getRes

setchannel :: String -> Int -> Int -> Cln SetChannel 
setchannel n b p = do 
    i <- tick 
    reqToHandle $ Req ("sendpay"::Text) (object [
          "id" .= n
        , "feebase" .= b
        , "feeppm" .= p 
        ]) (Just i) 
    getRes

getinfo :: Cln GetInfo 
getinfo = do 
    i <- tick 
    reqToHandle $ Req ("getinfo"::Text) (object []) (Just $ i )  
    getRes 

channelsbysource :: String -> Cln ListChannels
channelsbysource source = do 
    i <- tick
    reqToHandle $ Req ("listchannels"::Text) (object [ 
        "source" .= source 
        ]) (Just i)  
    getRes 

getroute :: ToJSON a => a -> a -> a -> Cln GetRoute 
getroute j m r = do
    i <- tick 
    reqToHandle $ Req ("getroute"::Text) (object [
          "id" .= j 
        , "msatoshi" .= m
        , "riskfactor" .= r
        ]) (Just i) 
    getRes

allchannels :: Cln ListChannels
allchannels = do 
    i <- tick
    reqToHandle $ Req ("listchannels"::Text) (object []) (Just $ i)     
    getRes 

allnodes :: Cln ListNodes
allnodes = do 
    i <- tick
    reqToHandle $ Req ("listnodes"::Text) (object []) (Just $ i)     
    getRes 

allforwards :: Cln ListForwards
allforwards = do 
    i <- tick 
    reqToHandle $ Req ("listforwards"::Text) (object [
        "status" .= ("settled"::Text) ]) (Just i )
    getRes

listfunds :: Cln ListFunds
listfunds = do 
    i <- tick
    reqToHandle $ Req ("listfunds"::Text) (object []) (Just $ i) 
    getRes 

fromInit :: Value -> String
fromInit v = case fromJSON v of 
    Success (InitConfig f g) -> f <> "/" <> g 
    otherwise -> "" 
data InitConfig = InitConfig String String deriving (Generic) 
instance FromJSON InitConfig where 
    parseJSON (Object v) = do 
        x <- v .: "configuration"  
        InitConfig <$> (x .: "lightning-dir") 
                   <*> (x .: "rpc-file")
    parseJSON _ = mempty
instance ToJSON InitConfig where 
    toJSON (InitConfig x y) = object ["home" .= (x <> y) ] 


