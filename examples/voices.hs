
{-# LANGUAGE GADTs #-}

import Music.Prelude
import Control.Lens (set)
import qualified Music.Score as S

subj :: Voice (Maybe Pitch)
subj = mconcat [c',ab,db',e,f,g,ab,bb,c']

type Chorale = [Voice (Maybe Pitch)]

renderVoice :: IsPitch a => Voice (Maybe Pitch) -> Score a
renderVoice = fmap fromPitch . removeRests . renderAlignedVoice . aligned 0 0

-- renderChorale :: (IsPitch a, HasParts' a, S.Part a ~ Part) => Chorale -> Score a
renderChorale = catSep . fmap renderVoice

catSep = ppar . zipWith (set parts') (divide 100 mempty)

music :: Music
music = renderChorale [subj]

main = defaultMain music
