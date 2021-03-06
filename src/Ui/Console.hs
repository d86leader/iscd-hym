{-# LANGUAGE OverloadedStrings #-}
module Ui.Console
( runUi
) where


import Control.Arrow ((>>>))
import Data.Text (Text, append, snoc, pack, unpack)
import System.Console.ANSI (setSGRCode)
import System.Console.ANSI.Types (SGR(SetColor), ConsoleLayer(..)
                                 ,ColorIntensity(Dull), Color(Black, White))

import qualified Data.Text as Text
import qualified Data.Text.IO as Text.IO
import qualified Data.Map as Map

import Parse (parseString)
import Edit.Execute (runCommands)
import Edit.Effects (Buffer(..), Effects(..), Cursor(..)
                    ,newCursor, newAllCursors, runEffects)
import Util.Text (split2)


-- |Get user input from command line, parse it, execute it in free context, and
-- run this context to IO
runUi :: IO ()
runUi = do
    input <- getContents
    let buffer = Buffer{bufferBody      = ["foobar", "barbaz", "keklol", "gotcha"]
                       ,bufferFilename  = "None"
                       ,bufferCursors   = newAllCursors
                       ,bufferSize      = 4
                       ,bufferRegisters = Map.fromList [('"', [Text.empty])]
                       }
    let commands = parseString input
    let executed = runCommands commands buffer
    let effects = snd . runEffects $ executed
    evalEffects effects


runOneEffect :: Effects -> IO ()
runOneEffect (ConsoleLog text) = putStrLn . unpack $ text
runOneEffect (WriteFile buf) = putStrLn $ "(Pretend) file " ++ bufferFilename buf ++ " written"
runOneEffect (PrintBuffer buf) = printBuffer buf

evalEffects :: [Effects] -> IO ()
evalEffects = mapM_ runOneEffect


-- Printing routines

printBuffer :: Buffer -> IO ()
printBuffer buf =
    let lines = bufferBody buf
        cur   = bufferCursors buf
    in Map.toAscList >>> linewiseCursors >>> zipWith splitOnCur lines
       >>> map joinHighlight >>> Text.unlines
       >>> Text.IO.putStrLn
       $ cur
    where
    -- Make a list where if cursor was present as (x, cur) it stand on position x as Just cur
    linewiseCursors :: [(Int, Cursor)] -> [Maybe Cursor]
    linewiseCursors = makeList 1 where
        makeList :: Int -> [(Int, Cursor)] -> [Maybe Cursor]
        makeList _ [] = repeat Nothing -- so we have something to fold with
        makeList n curs@((ind, cur):rest)
            | n == ind  = (Just cur) : makeList (n+1) rest
            | n < ind   = Nothing : makeList (n+1) curs
    --
    -- Split text on cursor indicies if cursor is present
    splitOnCur :: Text -> Maybe Cursor -> Either Text (Text, Text, Text)
    splitOnCur text Nothing = Left text
    splitOnCur text (Just (Cursor l r)) = Right $ split2 (l, r) text
    --
    -- join the text and highlight the middle chunk
    joinHighlight :: Either Text (Text, Text, Text) -> Text
    joinHighlight (Left t) = t
    joinHighlight (Right (l, m, r)) =
        l `append` setCode `append` m `append` resetCode `append` r
    --
    -- colors for highlighting
    inverseBg = SetColor Background Dull White
    inverseFg = SetColor Foreground Dull Black
    inverse = [inverseBg, inverseFg]
    setCode = pack $ setSGRCode inverse
    resetCode = pack $ setSGRCode []
