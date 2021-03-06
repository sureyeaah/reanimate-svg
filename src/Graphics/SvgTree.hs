{-# LANGUAGE CPP #-}
-- | Module providing basic input/output for the SVG document,
-- for document building, please refer to Graphics.Svg.Types.
module Graphics.SvgTree
  ( -- * Saving/Loading functions
    loadSvgFile
  , parseSvgFile
  , unparse
  , xmlOfDocument
  , xmlOfTree
  , saveXmlFile

    -- * Manipulation functions
  , cssApply
  , cssRulesOfText
  -- , applyCSSRules
  -- , resolveUses

    -- * Type definitions
  , module Graphics.SvgTree.Types
  ) where

#if !MIN_VERSION_base(4,8,0)
import           Control.Applicative        ((<$>))
#endif

import           Control.Lens
import qualified Data.ByteString            as B
import           Data.List                  (foldl')
-- import qualified Data.Map                   as M
import qualified Data.Text                  as T
import           Text.XML.Light.Input       (parseXMLDoc)
import           Text.XML.Light.Output      (ppcTopElement, prettyConfigPP)

import           Graphics.SvgTree.CssParser (cssRulesOfText)
import           Graphics.SvgTree.CssTypes
import           Graphics.SvgTree.Types
import           Graphics.SvgTree.XmlParser

{-import Graphics.Svg.CssParser-}

-- | Try to load an svg file on disc and parse it as
-- a SVG Document.
loadSvgFile :: FilePath -> IO (Maybe Document)
loadSvgFile filename =
  parseSvgFile filename <$> B.readFile filename

-- | Parse an in-memory SVG file
parseSvgFile :: FilePath    -- ^ Source path/URL of the document, used
                            -- to resolve relative links.
             -> B.ByteString
             -> Maybe Document
parseSvgFile filename fileContent =
  parseXMLDoc fileContent >>= unparseDocument filename

-- | Save a svg Document on a file on disk.
saveXmlFile :: FilePath -> Document -> IO ()
saveXmlFile filePath =
    writeFile filePath . ppcTopElement prettyConfigPP . xmlOfDocument

cssDeclApplyer :: DrawAttributes -> CssDeclaration
               -> DrawAttributes
cssDeclApplyer value (CssDeclaration txt elems) =
   case lookup txt cssUpdaters of
     Nothing -> value
     Just f  -> f value elems
  where
    cssUpdaters = [(T.pack $ _attributeName n, u) |
                            (n, u) <- drawAttributesList]

-- | Rewrite a SVG Tree using some CSS rules.
--
-- This action will propagate the definition of the
-- css directly in each matched element.
cssApply :: [CssRule] -> Tree -> Tree
cssApply rules = zipTree go where
  go [] = None
  go ([]:_) = None
  go context@((t:_):_) = t & drawAttributes .~ attr'
   where
     matchingDeclarations =
         findMatchingDeclarations rules context
     attr = view drawAttributes t
     attr' = foldl' cssDeclApplyer attr matchingDeclarations

-- For every 'use' tag, try to resolve the geometry associated
-- with it and place it in the scene Tree. It is important to
-- resolve the 'use' tag before applying the CSS rules, as some
-- rules may apply some elements matching the children of "use".
-- resolveUses :: Document -> Document
-- resolveUses doc =
--   doc { _elements = mapTree fetchUses <$> _elements doc }
--   where
--     fetchUses (UseTree useInfo _) = UseTree useInfo $ search useInfo
--     fetchUses a                   = a
--
--     search nfo = M.lookup (_useName nfo) $ _definitions doc

-- -- | Rewrite the document by applying the CSS rules embedded
-- -- inside it.
-- applyCSSRules :: Document -> Document
-- applyCSSRules doc = doc
--     { _elements = cssApply (_styleRules doc) <$> _elements doc }
