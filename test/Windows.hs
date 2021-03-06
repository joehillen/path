{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Test suite.

module Windows (spec) where

import Control.Applicative
import Control.Monad
import Data.Aeson
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.Maybe
import Path
import Path.Internal
import Test.Hspec

-- | Test suite (Windows version).
spec :: Spec
spec =
  do describe "Parsing: Path Abs Dir" parseAbsDirSpec
     describe "Parsing: Path Rel Dir" parseRelDirSpec
     describe "Parsing: Path Abs File" parseAbsFileSpec
     describe "Parsing: Path Rel File" parseRelFileSpec
     describe "Operations: (</>)" operationAppend
     describe "Operations: stripDir" operationStripDir
     describe "Operations: isParentOf" operationIsParentOf
     describe "Operations: parent" operationParent
     describe "Operations: filename" operationFilename
     describe "Operations: dirname" operationDirname
     describe "Restrictions" restrictions
     describe "Aeson Instances" aesonInstances

-- | Restricting the input of any tricks.
restrictions :: Spec
restrictions =
  do parseFails "..\\"
     parseFails ".."
     parseFails "."
     parseSucceeds "a.." (Path "a..\\")
     parseSucceeds "..a" (Path "..a\\")
     parseFails "\\.."
     parseFails "C:\\foo\\..\\bar\\"
     parseFails "C:\\foo\\bar\\.."
  where parseFails x =
          it (show x ++ " should be rejected")
             (isNothing (void (parseAbsDir x) <|>
                         void (parseRelDir x) <|>
                         void (parseAbsFile x) <|>
                         void (parseRelFile x)))
        parseSucceeds x with =
          parserTest parseRelDir x (Just with)

-- | The 'dirname' operation.
operationDirname :: Spec
operationDirname = do
  it
    "dirname ($(mkAbsDir parent) </> $(mkRelFile dirname)) == dirname $(mkRelFile dirname) (unit test)"
    (dirname ($(mkAbsDir "C:\\chris\\") </> $(mkRelDir "bar")) ==
     dirname $(mkRelDir "bar"))
  it
    "dirname ($(mkRelDir parent) </> $(mkRelFile dirname)) == dirname $(mkRelFile dirname) (unit test)"
    (dirname ($(mkRelDir "home\\chris\\") </> $(mkRelDir "bar")) ==
     dirname $(mkRelDir "bar"))

-- | The 'filename' operation.
operationFilename :: Spec
operationFilename =
  do it "filename ($(mkAbsDir parent) </> $(mkRelFile filename)) == filename $(mkRelFile filename) (unit test)"
          (filename ($(mkAbsDir "C:\\chris\\") </>
                             $(mkRelFile "bar.txt")) ==
                                      filename $(mkRelFile "bar.txt"))

     it "filename ($(mkRelDir parent) </> $(mkRelFile filename)) == filename $(mkRelFile filename) (unit test)"
             (filename ($(mkRelDir "home\\chris\\") </>
                                $(mkRelFile "bar.txt")) ==
                                         filename $(mkRelFile "bar.txt"))

-- | The 'parent' operation.
operationParent :: Spec
operationParent =
  do it "parent (parent </> child) == parent"
        (parent ($(mkAbsDir "C:\\foo") </>
                    $(mkRelDir "bar")) ==
         $(mkAbsDir "C:\\foo"))
     it "parent \"\" == \"\""
        (parent $(mkAbsDir "C:\\") ==
         $(mkAbsDir "C:\\"))
     it "parent (parent \"\") == \"\""
        (parent (parent $(mkAbsDir "C:\\")) ==
         $(mkAbsDir "C:\\"))

-- | The 'isParentOf' operation.
operationIsParentOf :: Spec
operationIsParentOf =
  do it "isParentOf parent (parent </> child) (unit test)"
        (isParentOf
           $(mkAbsDir "C:\\\\\\bar\\")
           ($(mkAbsDir "C:\\\\\\bar\\") </>
            $(mkRelFile "bar\\foo.txt")))

     it "isParentOf parent (parent </> child) (unit test)"
        (isParentOf
           $(mkRelDir "bar\\")
           ($(mkRelDir "bar\\") </>
            $(mkRelFile "bob\\foo.txt")))

-- | The 'stripDir' operation.
operationStripDir :: Spec
operationStripDir =
  do it "stripDir parent (parent </> child) = child (unit test)"
        (stripDir $(mkAbsDir "C:\\\\\\bar\\")
                  ($(mkAbsDir "C:\\\\\\bar\\") </>
                   $(mkRelFile "bar\\foo.txt")) ==
         Just $(mkRelFile "bar\\foo.txt"))

     it "stripDir parent (parent </> child) = child (unit test)"
        (stripDir $(mkRelDir "bar\\")
                  ($(mkRelDir "bar\\") </>
                   $(mkRelFile "bob\\foo.txt")) ==
         Just $(mkRelFile "bob\\foo.txt"))

     it "stripDir parent parent = _|_"
        (stripDir $(mkAbsDir "C:\\home\\chris\\foo")
                  $(mkAbsDir "C:\\home\\chris\\foo") ==
         Nothing)

-- | The '</>' operation.
operationAppend :: Spec
operationAppend =
  do it "AbsDir + RelDir = AbsDir"
        ($(mkAbsDir "C:\\home\\") </>
         $(mkRelDir "chris") ==
         $(mkAbsDir "C:\\home\\chris\\"))
     it "AbsDir + RelFile = AbsFile"
        ($(mkAbsDir "C:\\home\\") </>
         $(mkRelFile "chris\\test.txt") ==
         $(mkAbsFile "C:\\home\\chris\\test.txt"))
     it "RelDir + RelDir = RelDir"
        ($(mkRelDir "home\\") </>
         $(mkRelDir "chris") ==
         $(mkRelDir "home\\chris"))
     it "RelDir + RelFile = RelFile"
        ($(mkRelDir "home\\") </>
         $(mkRelFile "chris\\test.txt") ==
         $(mkRelFile "home\\chris\\test.txt"))

-- | Tests for the tokenizer.
parseAbsDirSpec :: Spec
parseAbsDirSpec =
  do failing ""
     failing ".\\"
     failing "foo.txt"
     succeeding "C:\\" (Path "C:\\")
     succeeding "C:\\\\" (Path "C:\\\\")
     -- succeeding "C:\\\\\\foo\\\\bar\\\\mu\\" (Path "C:\\foo\\bar\\mu\\") FIXME
     -- succeeding "C:\\\\\\foo\\\\bar\\\\mu" (Path "C:\\foo\\bar\\mu\\") FIXME
     -- succeeding "C:\\\\\\foo\\\\bar\\.\\\\mu" (Path "C:\\foo\\bar\\mu\\") FIXME

  where failing x = parserTest parseAbsDir x Nothing
        succeeding x with = parserTest parseAbsDir x (Just with)

-- | Tests for the tokenizer.
parseRelDirSpec :: Spec
parseRelDirSpec =
  do failing ""
     -- failing "/" FIXME
     -- failing "//" FIXME
     -- succeeding "~/" (Path "~/") -- https://github.com/chrisdone/path/issues/19
     -- failing "\\" FIXME
     failing ".\\"
     failing ".\\.\\"
     failing "\\\\"
     failing "\\\\\\foo\\\\bar\\\\mu\\"
     failing "\\\\\\foo\\\\bar\\\\\\\\mu"
     failing "\\\\\\foo\\\\bar\\.\\\\mu"
     succeeding "..." (Path "...\\")
     succeeding "foo.bak" (Path "foo.bak\\")
     succeeding ".\\foo" (Path "foo\\")
     succeeding ".\\.\\foo" (Path "foo\\")
     succeeding ".\\foo\\.\\bar" (Path "foo\\bar\\")
     succeeding "foo\\\\bar\\\\mu\\\\" (Path "foo\\bar\\mu\\")
     succeeding "foo\\\\bar////mu" (Path "foo\\bar\\mu\\")
     succeeding "foo\\\\bar\\.\\\\mu" (Path "foo\\bar\\mu\\")

  where failing x = parserTest parseRelDir x Nothing
        succeeding x with = parserTest parseRelDir x (Just with)

-- | Tests for the tokenizer.
parseAbsFileSpec :: Spec
parseAbsFileSpec =
  do failing ""
     failing ".\\"
     failing "\\."
     failing "\\foo\\bar\\."
     failing "~\\"
     failing ".\\foo.txt"
     failing "\\"
     failing "\\\\"
     failing "\\\\\\foo\\\\bar\\\\mu\\"
     -- succeeding "\\..." (Path "\\...") FIXME
     -- succeeding "\\foo.txt" (Path "\\foo.txt") FIXME
     -- succeeding "C:\\\\\\foo\\\\bar\\\\\\\\mu.txt" (Path "C:\\foo\\bar\\mu.txt") FIXME
     -- succeeding "C:\\\\\\foo\\\\bar\\.\\\\mu.txt" (Path "C:\\foo\\bar\\mu.txt") FIXME

  where failing x = parserTest parseAbsFile x Nothing
        succeeding x with = parserTest parseAbsFile x (Just with)

-- | Tests for the tokenizer.
parseRelFileSpec :: Spec
parseRelFileSpec =
  do failing ""
     failing "\\"
     failing "\\\\"
     failing "~\\"
     failing "\\"
     failing ".\\"
     failing "a\\."
     failing "a\\..\\b"
     failing "a\\.."
     failing "..\\foo.txt"
     failing "\\\\"
     failing "\\\\\\foo\\\\bar\\\\mu\\"
     failing "\\\\\\foo\\\\bar\\\\\\\\mu"
     failing "\\\\\\foo\\\\bar\\.\\\\mu"
     succeeding "a.." (Path "a..")
     succeeding "..." (Path "...")
     succeeding "foo.txt" (Path "foo.txt")
     succeeding ".\\foo.txt" (Path "foo.txt")
     succeeding ".\\.\\foo.txt" (Path "foo.txt")
     succeeding ".\\foo\\.\\bar.txt" (Path "foo\\bar.txt")
     succeeding "foo\\\\bar\\\\mu.txt" (Path "foo\\bar\\mu.txt")
     succeeding "foo\\\\bar\\\\\\\\mu.txt" (Path "foo\\bar\\mu.txt")
     succeeding "foo\\\\bar\\.\\\\mu.txt" (Path "foo\\bar\\mu.txt")

  where failing x = parserTest parseRelFile x Nothing
        succeeding x with = parserTest parseRelFile x (Just with)

-- | Parser test.
parserTest :: (Show a1,Show a,Eq a1)
           => (a -> Maybe a1) -> a -> Maybe a1 -> SpecWith ()
parserTest parser input expected =
  it ((case expected of
         Nothing -> "Failing: "
         Just{} -> "Succeeding: ") ++
      "Parsing " ++
      show input ++
      " " ++
      case expected of
        Nothing -> "should fail."
        Just x -> "should succeed with: " ++ show x)
     (actual `shouldBe` expected)
  where actual = parser input

-- | Tests for the 'ToJSON' and 'FromJSON' instances
--
-- Can't use overloaded strings due to some weird issue with bytestring-0.9.2.1 / ghc-7.4.2:
-- https://travis-ci.org/sjakobi/path/jobs/138399072#L989
aesonInstances :: Spec
aesonInstances =
  do it "Decoding \"[\"C:\\\\foo\\\\bar\"]\" as a [Path Abs Dir] should succeed." $
       eitherDecode (LBS.pack "[\"C:\\\\foo\\\\bar\"]") `shouldBe` Right [Path "C:\\foo\\bar\\" :: Path Abs Dir]
     it "Decoding \"[\"C:\\foo\\bar\"]\" as a [Path Rel Dir] should fail." $
       decode (LBS.pack "[\"C:\\foo\\bar\"]") `shouldBe` (Nothing :: Maybe [Path Rel Dir])
     it "Encoding \"[\"C:\\foo\\bar\\mu.txt\"]\" should succeed." $
       encode [Path "C:\\foo\\bar\\mu.txt" :: Path Abs File] `shouldBe` (LBS.pack "[\"C:\\\\foo\\\\bar\\\\mu.txt\"]")
