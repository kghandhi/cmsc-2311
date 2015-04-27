import Data.Maybe
import Data.Ord
import Data.List hiding (insert, empty, findIndex)
import qualified Data.List as L (map)
import Data.Map hiding (foldl)
import qualified Data.Map as M (map)
import Network.HTTP
import Text.HTML.TagSoup
import Control.Monad

type PrimitiveModel = Map (String, String) [String]
type ProcessModel = [(String, [(Int, Int)])]


openURL :: String -> IO String
openURL url = simpleHTTP (getRequest url) >>= getResponseBody

harvest :: [Tag String] -> [Tag String]
harvest body =
  foldl (++) [] (sections (~== "<p>") body)

getBody :: [Tag String] -> [Tag String]
getBody tags =
  takeWhile (~/= "<div id=back>") $ head $ sections (~== "<div id=body>") tags

extractWords :: [Tag String] -> [String]
extractWords tags = words $ innerText $ harvest $ getBody tags

makePairs :: [String] -> [(String, String)]
makePairs txt = zip txt (drop 1 txt)

makePrim :: [String] -> PrimitiveModel
makePrim txt = helper (empty :: PrimitiveModel) txt
  where
    helper acc (x:y:[]) = acc
    helper acc (x:y:z:rest) = if member (x,y) acc then helper (adjust (++ [z]) (x,y) acc) (y:z:rest)
                              else helper (insert (x, y) [z] acc) (y:z:rest)

makeFreq :: PrimitiveModel -> Map (String, String) [(Int, String)]
makeFreq prim = M.map frequency prim

frequency :: Ord a => [a] -> [(Int, a)]
frequency xs = sortBy (flip $ comparing fst) $ L.map (\x -> (length x, head x)) (group $ sort xs)

makeProcess :: Map (String, String) [(Int, String)] -> ProcessModel
makeProcess freq = fst $ mapAccumWithKey mapper [] freq where
  --mapper :: ProcessModel -> (String, String) -> [(Int, String)] -> [(String, [(Int, Int)])]
  mapper process (x,y) zs = ((y, L.map (\(f,z) -> (f, findIndex (y,z) freq)) zs):process, zs)

suck :: [String] -> ProcessModel
suck txt = reverse $ makeProcess $ makeFreq $ makePrim txt

main = do
  tags <- fmap parseTags $ openURL "http://muse.jhu.edu/journals/postmodern_culture/v024/24.1.mickalites.html"
  --mapM (\tup -> writeFile "sokal.model" (show tup)) $ suck $ extractWords tags
  --mapM_ (putStrLn . show) (suck $ extractWords tags)
  writeFile "sokal.model" $ join (intersperse "\n" (L.map show (suck $ extractWords tags)))