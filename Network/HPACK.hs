-- | HPACK: encoding and decoding a header set.
module Network.HPACK (
  -- * Encoding and decoding
    HPACKEncoding
  , HPACKDecoding
  -- * Request
  , encodeRequestHeader
  , decodeRequestHeader
  -- * Response
  , encodeResponseHeader
  , decodeResponseHeader
  -- * Contenxt
  , Context
  , newContext
  -- * Errors for decoding
  , DecodeError(..)
  -- * Headers
  , HeaderSet
  , Header
  , HeaderName
  , HeaderValue
  -- * Basic types
  , ByteStream
  , Size
  , Index
  ) where

import Control.Applicative ((<$>))
import Control.Arrow (second)
import Control.Exception (throwIO)
import Network.HPACK.Context (Context, newContext, HeaderSet)
import Network.HPACK.HeaderBlock (toHeaderBlock, fromHeaderBlock, toByteStream, fromByteStream)
import Network.HPACK.Huffman (huffmanEncodeInRequest, huffmanDecodeInRequest, huffmanEncodeInResponse, huffmanDecodeInResponse)
import Network.HPACK.Table (Size)
import Network.HPACK.Types (ByteStream, DecodeError(..), Header, HeaderName, HeaderValue, Index)

----------------------------------------------------------------

-- | HPACK encoding, from 'HeaderSet' to 'ByteStream'.
type HPACKEncoding = Context -> HeaderSet  -> IO (Context, ByteStream)

-- | HPACK decoding, from 'ByteStream' to 'HeaderSet'.
type HPACKDecoding = Context -> ByteStream -> IO (Context, HeaderSet)

----------------------------------------------------------------

-- | Converting 'HeaderSet' for HTTP request to the low level format.
encodeRequestHeader :: HPACKEncoding
encodeRequestHeader ctx hs = second toBS <$> toHeaderBlock ctx hs
  where
    toBS = toByteStream huffmanEncodeInRequest

-- | Converting the low level format for HTTP request to 'HeaderSet'.
--   'DecodeError' would be thrown.
decodeRequestHeader :: HPACKDecoding
decodeRequestHeader ctx bs = either throwIO (fromHeaderBlock ctx) ehb
  where
    ehb = fromByteStream huffmanDecodeInRequest bs

----------------------------------------------------------------

-- | Converting 'HeaderSet' for HTTP response to the low level format.
encodeResponseHeader :: HPACKEncoding
encodeResponseHeader ctx hs = second toBS <$> toHeaderBlock ctx hs
  where
    toBS = toByteStream huffmanEncodeInResponse

-- | Converting the low level format for HTTP response to 'HeaderSet'.
--   'DecodeError' would be thrown.
decodeResponseHeader :: HPACKDecoding
decodeResponseHeader ctx bs = either throwIO (fromHeaderBlock ctx) ehb
  where
    ehb = fromByteStream huffmanDecodeInResponse bs
