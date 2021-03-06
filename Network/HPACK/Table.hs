{-# LANGUAGE TupleSections, RecordWildCards, CPP #-}

module Network.HPACK.Table (
  -- * dynamic table
    DynamicTable
  , newDynamicTableForEncoding
  , newDynamicTableForDecoding
  , renewDynamicTable
  , printDynamicTable
  , isDynamicTableEmpty
  -- * Insertion
  , insertEntry
  -- * Header to index
  , HeaderCache(..)
  , lookupTable
  -- * Entry
  , module Network.HPACK.Table.Entry
  -- * Which tables
  , WhichTable(..)
  , which
  ) where

#if __GLASGOW_HASKELL__ < 709
import Control.Applicative ((<$>))
#endif
import Control.Exception (throwIO)
import Network.HPACK.Table.Dynamic
import Network.HPACK.Table.Entry
import qualified Network.HPACK.Table.DoubleHashMap as DHM
import Network.HPACK.Table.Static
import Network.HPACK.Types

----------------------------------------------------------------

-- | Which table does `Index` refer to?
data WhichTable = InDynamicTable | InStaticTable deriving (Eq,Show)

-- | Is header key-value stored in the tables?
data HeaderCache = None
                 | KeyOnly WhichTable Index
                 | KeyValue WhichTable Index deriving Show

----------------------------------------------------------------

-- | Resolving an index from a header.
--   Static table is prefer to dynamic table.
lookupTable :: Header -> DynamicTable -> HeaderCache
lookupTable h hdrtbl = case reverseIndex hdrtbl of
    Nothing            -> None
    Just rev -> case DHM.search h rev of
        DHM.N       -> case mstatic of
            DHM.N       -> None
            DHM.K  sidx -> KeyOnly  InStaticTable (fromSIndexToIndex hdrtbl sidx)
            DHM.KV sidx -> KeyValue InStaticTable (fromSIndexToIndex hdrtbl sidx)
        DHM.K hidx  -> case mstatic of
            DHM.N       -> KeyOnly  InDynamicTable (fromHIndexToIndex hdrtbl hidx)
            DHM.K  sidx -> KeyOnly  InStaticTable (fromSIndexToIndex hdrtbl sidx)
            DHM.KV sidx -> KeyValue InStaticTable (fromSIndexToIndex hdrtbl sidx)
        DHM.KV hidx -> case mstatic of
            DHM.N       -> KeyValue InDynamicTable (fromHIndexToIndex hdrtbl hidx)
            DHM.K  _    -> KeyValue InDynamicTable (fromHIndexToIndex hdrtbl hidx)
            DHM.KV sidx -> KeyValue InStaticTable (fromSIndexToIndex hdrtbl sidx)
  where
    mstatic = DHM.search h staticHashPSQ

----------------------------------------------------------------

isIn :: Int -> DynamicTable -> Bool
isIn idx DynamicTable{..} = idx > staticTableSize

-- | Which table does 'Index' belong to?
which :: DynamicTable -> Index -> IO (WhichTable, Entry)
which hdrtbl idx
  | idx `isIn` hdrtbl  = (InDynamicTable,) <$> toHeaderEntry hdrtbl hidx
  | isSIndexValid sidx = return (InStaticTable, toStaticEntry sidx)
  | otherwise          = throwIO $ IndexOverrun idx
  where
    hidx = fromIndexToHIndex hdrtbl idx
    sidx = fromIndexToSIndex hdrtbl idx
