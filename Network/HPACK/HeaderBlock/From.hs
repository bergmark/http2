{-# LANGUAGE BangPatterns, CPP #-}

module Network.HPACK.HeaderBlock.From (
    fromHeaderBlock
  , decodeStep
  ) where

#if __GLASGOW_HASKELL__ < 709
import Control.Applicative ((<$>))
#endif
import Network.HPACK.Builder
import Network.HPACK.HeaderBlock.HeaderField
import Network.HPACK.Table
import Network.HPACK.Types

----------------------------------------------------------------

type Ctx = (DynamicTable, Builder Header)
type Step = Ctx -> HeaderField -> IO Ctx

-- | Decoding 'HeaderBlock' to 'HeaderList'.
fromHeaderBlock :: DynamicTable
                -> HeaderBlock
                -> IO (DynamicTable, HeaderList)
fromHeaderBlock !hdrtbl rs = decodeLoop rs (hdrtbl,empty)

----------------------------------------------------------------

decodeLoop :: HeaderBlock -> Ctx -> IO (DynamicTable, HeaderList)
decodeLoop (r:rs) !hdrtbl = decodeStep hdrtbl r >>= decodeLoop rs
decodeLoop []     !hdrtbl = decodeFinal hdrtbl

----------------------------------------------------------------

-- | Decoding step for one 'HeaderField'. Exporting for the
--   test purpose.
decodeStep :: Step
decodeStep (!hdrtbl,!builder) (ChangeTableSize siz) = do
    hdrtbl' <- renewDynamicTable siz hdrtbl
    return (hdrtbl',builder)
decodeStep (!hdrtbl,!builder) (Indexed idx) = do
      w <- which hdrtbl idx
      case w of
          (InStaticTable, e) -> do
              let b = builder << fromEntry e
              return (hdrtbl,b)
          (InDynamicTable, e) -> do
              let b = builder << fromEntry e
              return (hdrtbl,b)
decodeStep (!hdrtbl,!builder) (Literal NotAdd naming v) = do
    k <- fromNaming naming hdrtbl
    let b = builder << (k,v)
    return (hdrtbl, b)
decodeStep (!hdrtbl,!builder) (Literal Never naming v) = do
    k <- fromNaming naming hdrtbl
    let b = builder << (k,v)
    return (hdrtbl, b)
decodeStep (!hdrtbl,!builder) (Literal Add naming v) = do
    k <- fromNaming naming hdrtbl
    let h = (k,v)
        e = toEntry (k,v)
        b = builder << h
    hdrtbl' <- insertEntry e hdrtbl
    return (hdrtbl',b)

decodeFinal :: Ctx -> IO (DynamicTable, HeaderList)
decodeFinal (!hdrtbl, !builder) = return (hdrtbl, run builder)

----------------------------------------------------------------

fromNaming :: Naming -> DynamicTable -> IO HeaderName
fromNaming (Lit k)   _   = return k
fromNaming (Idx idx) hdrtbl = entryHeaderName . snd <$> which hdrtbl idx
