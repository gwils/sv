module Data.CSV.Arbitraries where

import Control.Applicative ((<$>), liftA2, liftA3)
import Data.Separated      (Pesarated (Pesarated), Separated (Separated), Separated1 (Separated1))
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Data.CSV.CSV        (CSV (CSV), FinalRecord (FinalRecord), Records (Records), RecordSet (RecordSet))
import Data.CSV.Field      (Field (QuotedF, UnquotedF))
import Data.CSV.Record     (Record (Record), NonEmptyRecord (SingleFieldNER, MultiFieldNER))
import Text.Between        (Between (Between))
import Text.Newline        (Newline (CR, CRLF, LF))
import Text.Quote          (Escaped (SeparatedByEscapes), Quote (SingleQuote, DoubleQuote), Quoted (Quoted))

genCsv :: Gen Char -> Gen spc -> Gen s1 -> Gen s2 -> Gen (CSV spc s1 s2)
genCsv sep spc s1 s2 =
  let rs = genRecordSet spc s1 s2
  in  liftA2 CSV sep rs

genNewline :: Gen Newline
genNewline =
  -- TODO put CR back in
  Gen.element [CRLF, LF]

genSep :: Gen Char
genSep =
  Gen.element ['|', ',']

genFinalRecord :: Gen spc -> Gen s1 -> Gen s2 -> Gen (FinalRecord spc s1 s2)
genFinalRecord spc s1 s2 =
  FinalRecord <$> Gen.maybe (genNonEmptyRecord spc s1 s2)

genBetween :: Gen spc -> Gen str -> Gen (Between spc str)
genBetween spc str =
  liftA3 Between spc str spc

genQuote :: Gen Quote
genQuote =
  Gen.element [SingleQuote, DoubleQuote]

genEscaped :: Gen a -> Gen (Escaped a)
genEscaped a =
  SeparatedByEscapes <$> Gen.nonEmpty (Range.linear 1 5) a

genQuoted :: Gen a -> Gen (Quoted a)
genQuoted =
  liftA2 Quoted genQuote . genEscaped

genField :: Gen spc -> Gen s1 -> Gen s2 -> Gen (Field spc s1 s2)
genField spc s1 s2 =
  Gen.choice [
    UnquotedF <$> s1
  , QuotedF <$> genBetween spc (genQuoted s2)
  ]

genRecord :: Gen spc -> Gen s1 -> Gen s2 -> Gen (Record spc s1 s2)
genRecord spc s1 s2 =
  Record <$> Gen.nonEmpty (Range.linear 1 50) (genField spc s1 s2)

genNonEmptyRecord :: Gen spc -> Gen s1 -> Gen s2 -> Gen (NonEmptyRecord spc s1 s2)
genNonEmptyRecord spc s1 s2 =
  let f  = genField spc s1 s2
      f' = genField spc s2 s2
  in  Gen.choice [
    SingleFieldNER <$> f
  , MultiFieldNER <$> f' <*> Gen.nonEmpty (Range.linear 1 50) f'
  ]

genRecords :: Gen spc -> Gen str -> Gen (Records spc str)
genRecords spc str =
  Records <$> genPesarated spc str str

genRecordSet :: Gen spc -> Gen s1 -> Gen s2 -> Gen (RecordSet spc s1 s2)
genRecordSet spc s1 s2 = RecordSet <$> genRecords spc s2 <*> genFinalRecord spc s1 s2

genPesarated :: Gen spc -> Gen s1 -> Gen s2 -> Gen (Pesarated Newline (Record spc s1 s2))
genPesarated spc s1 s2 =
  let r = genRecord spc s1 s2
  in  Pesarated <$> genSeparated r genNewline

genSeparated :: Gen a -> Gen b -> Gen (Separated a b)
genSeparated a b =
  Separated <$> Gen.list (Range.linear 0 10000) (liftA2 (,) a b)

