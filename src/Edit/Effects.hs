{-# LANGUAGE GADTSyntax, DeriveFunctor #-}
module Edit.Effects
( Buffer(..)  -- |State of editing a text file
, editBody
, editFileName
, editCursors

, Effects(..) -- |Side effects when editing a file
, EffectAtom  -- |A monad writer that tracks side effects of editing
, EditAtom    -- |Effect atom with buffer embedded. Main return type of edit
              --  functions
, writer, listen, pass -- |Monad writer methods
, runEffects

, Cursor(..)
, newCursor
) where

import Data.Text (Text)
import Data.Map.Strict (Map)
import Data.Vector (Vector)
import Control.Monad.Writer.Lazy (Writer, writer, listen, pass, runWriter)


-- |Left and right bounds of a cursor on a single line.
-- Inclusive, which means that if you delete selected (Cursor l r) text it will
-- delete character at l and character at r.
data Cursor = Cursor Int Int
    deriving (Show)
newCursor = Cursor 0 0


-- |A buffer that is modified by commands
data Buffer = Buffer {
     body :: Vector Text
    ,filename :: FilePath
    ,cursors :: Map Int Cursor
    -- TODO: undo history, redo history
} deriving (Show)
-- Quickly modify buffer content
editBody :: (Vector Text -> Vector Text) -> Buffer -> Buffer
editBody f buf = let text = body buf
                 in buf {body = f text}
editFileName :: (FilePath -> FilePath) -> Buffer -> Buffer
editFileName f buf = let path = filename buf
                 in buf {filename = f path}
editCursors :: (Map Int Cursor -> Map Int Cursor) -> Buffer -> Buffer
editCursors f buf = let cur = cursors buf
                    in buf {cursors = f cur}

-- |Side effects that can occur when execting commands
data Effects where
    ConsoleLog :: Text -> Effects
    WriteFile :: Buffer -> Effects
    PrintBuffer :: Buffer -> Effects
    -- something else?
    --
    deriving (Show)

type EffectAtom a = Writer [Effects] a
type EditAtom = EffectAtom Buffer

runEffects :: EffectAtom a -> (a, [Effects])
runEffects = runWriter
