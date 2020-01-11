{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}

------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

-- |
-- Copyright   : (c) Hans Hoglund 2012
--
-- License     : BSD-style
--
-- Maintainer  : hans@hanshoglund.se
-- Stability   : experimental
-- Portability : non-portable (TF,GNTD)
--
-- Standard music representation and export.
module Music.Prelude.Standard
  ( module Music.Pitch,
    module Music.Dynamics,
    module Music.Articulation,
    module Music.Parts,
    module Music.Score,
    Music,
    StandardNote,
    defaultMain,

    -- * Lens re-exports
    set,
    over,
    view,

    -- ** Orchestration
    singleParts,
    doubleParts,
    doublePartsF,
    doublePartsInOctave,
    -- TODO remove the below:
    asScore,
    asVoice,
    asTrack,
    asNote,
    fromPitch'',
  )
where

import qualified Codec.Midi
import Control.Lens (mapped, over, set, view)
import qualified Data.Music.MusicXml
import Data.Typeable
import Music.Articulation
import Music.Dynamics
import Music.Parts
import Music.Pitch
import Music.Score hiding (Articulation, Clef (..), Dynamics, Fifths, Interval, Part, Pitch)
import Music.Score.Export.StandardNotation (Asp1, LilypondLayout (..), LilypondOptions (..), defaultLilypondOptions, fromAspects, runIOExportM, toLy, toMidi, toXml)
import qualified Music.Score.Part
import qualified System.Environment
import qualified Text.Pretty

asNote :: StandardNote -> StandardNote
asNote = id

asScore :: Score StandardNote -> Score StandardNote
asScore = id

asVoice :: Voice StandardNote -> Voice StandardNote
asVoice = id

asTrack :: Track StandardNote -> Track StandardNote
asTrack = id

type StandardNote = Asp1

type Music = Score StandardNote

-- TODO set logging level
-- TODO more options?
data CommandLineOptions
  = ToXml FilePath
  | ToLy LilypondOptions FilePath
  | ToMidi FilePath
  | Help

-- TOOD Proper parser using optparse-applicative or optparse-generic
parse :: Applicative m => [String] -> m CommandLineOptions
parse ("-f" : "xml" : "-o" : path : _) = pure $ ToXml path
parse ("-f" : "ly" : "-o" : path : _) = pure $ ToLy defaultLilypondOptions path
parse ("-f" : "ly" : "--layout=inline" : "-o" : path : _) = pure $ ToLy (defaultLilypondOptions {layout = LilypondInline}) path
parse ("-f" : "mid" : "-o" : path : _) = pure $ ToMidi path
parse _ = pure Help

defaultMain :: Music -> IO ()
defaultMain music = do
  args <- System.Environment.getArgs
  opts <- parse args
  case opts of
    Help ->
      putStrLn
        "Usage: <executable> -f [xml|ly|mid] -o PATH"
    ToMidi path -> do
      midi <- runIOExportM $ toMidi music
      Codec.Midi.exportFile path midi
    ToLy opts path -> do
      work <- runIOExportM $ fromAspects music
      (h, ly) <- runIOExportM $ toLy opts work
      let ly' = h ++ show (Text.Pretty.pretty ly)
      -- TODO use ByteString/builders, not String?
      writeFile path ly'
    ToXml path -> do
      work <- runIOExportM $ fromAspects music
      work' <- runIOExportM $ toXml work
      -- TODO use ByteString/builders, not String?
      writeFile path $ Data.Music.MusicXml.showXml work'

-- TODO remove!
fromPitch'' :: IsPitch a => Pitch -> a
fromPitch'' = fromPitch
{-# DEPRECATED fromPitch'' "Use fromPitch (no primes!)" #-}

-- | Orchestrate in the given parts.
singleParts :: (Monoid a, Semigroup a, HasParts' a) => [Music.Score.Part.Part a] -> [a] -> a
singleParts ens = ppar . zipWith (set parts') (reverse $ ens)

-- | Orchestrate by doubling the given music in all given parts.
--
-- >>> doublePartsInOctave [violins,flutes] $ pseq[c,d,e]
doubleParts :: (Monoid a, HasParts' a) => [Music.Score.Part.Part a] -> a -> a
doubleParts ps x = mconcat $ fmap (\p -> set parts' p x) ps

doublePartsF :: (Monoid (f a), HasParts' a, Functor f) => [Music.Score.Part.Part a] -> f a -> f a
doublePartsF ps x = mconcat $ fmap (\p -> set (mapped . parts') p x) ps

-- | Orchestrate by doubling in all given parts.
--
-- >>> doublePartsInOctave [(violins,0),(flutes,1)] $ pseq[c,d,e]
doublePartsInOctave :: (Monoid a, Transposable a, HasParts' a) => [(Music.Score.Part.Part a, Int)] -> a -> a
doublePartsInOctave ps x = mconcat $ fmap (\(p, n) -> set parts' p $ octavesUp (fromIntegral n) x) ps

doublePartsInOctaveF :: (Monoid (f a), Transposable a, HasParts' a, Functor f) => [(Music.Score.Part.Part a, Int)] -> f a -> f a
doublePartsInOctaveF ps x = mconcat $ fmap (\(p, n) -> set (mapped . parts') p $ fmap (octavesUp (fromIntegral n)) x) ps
