-- @+leo-ver=5-thin
-- @+node:gcross.20101114125204.1259: * @file tests.hs
-- @@language haskell

-- @+<< Language extensions >>
-- @+node:gcross.20101114125204.1281: ** << Language extensions >>
{-# LANGUAGE UnicodeSyntax #-}
-- @-<< Language extensions >>

-- @+<< Import needed modules >>
-- @+node:gcross.20101114125204.1260: ** << Import needed modules >>
import Control.Exception
import Control.Monad
import Control.Monad.Trans.Class (MonadTrans(..))
import Control.Monad.Trans.Writer

import qualified Data.Sequence as Seq
import Data.Serialize

import Test.Framework
import Test.Framework.Providers.HUnit
import Test.HUnit

import Control.Monad.Trans.Visitor
import Control.Monad.Trans.Visitor.Path
-- @-<< Import needed modules >>

-- @+others
-- @-others

main = defaultMain
    -- @+<< Tests >>
    -- @+node:gcross.20101114125204.1267: ** << Tests >>
    -- @+others
    -- @+node:gcross.20110923164140.1187: *3* Control.Monad.Trans.Visitor
    [testGroup "Control.Monad.Trans.Visitor"
        -- @+others
        -- @+node:gcross.20110722110408.1173: *4* gatherVisitorResults
        [testGroup "gatherVisitorResults"
            -- @+others
            -- @+node:gcross.20110722110408.1177: *5* return
            [testCase "return" $ gatherVisitorResults (return ()) @?= [()]
            -- @+node:gcross.20110722110408.1174: *5* mzero
            ,testCase "mzero" $ gatherVisitorResults (mzero :: Visitor ()) @?= []
            -- @+node:gcross.20110722110408.1178: *5* mplus
            ,testCase "mplus" $ gatherVisitorResults (return 1 `mplus` return 2) @?= [1,2]
            -- @+node:gcross.20110722110408.1179: *5* cache
            ,testCase "cache" $ gatherVisitorResults (cache 42) @?= [42::Int]
            -- @-others
            ]
        -- @+node:gcross.20110923164140.1202: *4* runVisitorT
        ,testGroup "runVisitorT"
            -- @+others
            -- @+node:gcross.20110923164140.1203: *5* Writer
            [testCase "Writer" $
                (runWriter . runVisitorT $ do
                    cache [1 :: Int] >>= lift . tell
                    (lift (tell [2]) `mplus` lift (tell [3]))
                    return 42
                ) @?= ((),[1,2,3])
            -- @-others
            ]
        -- @+node:gcross.20110923164140.1211: *4* runVisitorTAndGatherResults
        ,testGroup "runVisitorTAndGatherResults"
            -- @+others
            -- @+node:gcross.20110923164140.1212: *5* Writer
            [testCase "Writer" $
                (runWriter . runVisitorTAndGatherResults $ do
                    cache [1 :: Int] >>= lift . tell
                    (lift (tell [2]) `mplus` lift (tell [3]))
                    return 42
                ) @?= ([42,42],[1,2,3])
            -- @-others
            ]
        -- @-others
        ]
    -- @+node:gcross.20110923164140.1188: *3* Control.Monad.Trans.Visitor.Path
    ,testGroup "Control.Monad.Trans.Visitor.Path"
        -- @+others
        -- @+node:gcross.20110923164140.1189: *4* walkVisitor
        [testGroup "walkVisitor"
            -- @+others
            -- @+node:gcross.20110923164140.1191: *5* null path
            [testCase "null path" $ (gatherVisitorResults . walkVisitor Seq.empty) (return 42) @?= [42]
            -- @+node:gcross.20110923164140.1200: *5* cache
            ,testCase "cache" $ do (gatherVisitorResults . walkVisitor (Seq.singleton (CacheStep (encode (42 :: Int))))) (cache (undefined :: Int)) @?= [42]
            -- @+node:gcross.20110923164140.1199: *5* choice
            ,testCase "choice" $ do
                (gatherVisitorResults . walkVisitor (Seq.singleton (ChoiceStep False))) (return 42 `mplus` undefined) @?= [42]
                (gatherVisitorResults . walkVisitor (Seq.singleton (ChoiceStep True))) (undefined `mplus` return 42) @?= [42]
            -- @+node:gcross.20110923164140.1192: *5* errors
            ,testGroup "errors"
                -- @+others
                -- @+node:gcross.20110923164140.1193: *6* DeadEnd (return)
                [testCase "DeadEnd (return)" $
                    try (
                        evaluate
                        .
                        gatherVisitorResults
                        $
                        walkVisitor (Seq.singleton (undefined :: VisitorStep)) (return (undefined :: Int))
                    ) >>= (@?= Left DeadEnd)
                -- @+node:gcross.20110923164140.1195: *6* DeadEnd (mzero)
                ,testCase "DeadEnd (mzero)" $
                    try (
                        evaluate
                        .
                        gatherVisitorResults
                        $
                        walkVisitor (Seq.singleton (undefined :: VisitorStep)) (mzero :: Visitor Int)
                    ) >>= (@?= Left DeadEnd)
                -- @+node:gcross.20110923164140.1196: *6* ChoiceStepAtCachePoint
                ,testCase "ChoiceStepAtCachePoint" $
                    try (
                        evaluate
                        .
                        gatherVisitorResults
                        $
                        walkVisitor (Seq.singleton (ChoiceStep undefined :: VisitorStep)) (cache undefined :: Visitor Int)
                    ) >>= (@?= Left ChoiceStepAtCachePoint)
                -- @+node:gcross.20110923164140.1198: *6* CacheStepAtChoicePoint
                ,testCase "CacheStepAtChoicePoint" $
                    try (
                        evaluate
                        .
                        gatherVisitorResults
                        $
                        walkVisitor (Seq.singleton (CacheStep undefined :: VisitorStep)) (undefined `mplus` undefined :: Visitor Int)
                    ) >>= (@?= Left CacheStepAtChoicePoint)
                -- @-others
                ]
            -- @-others
            ]
        -- @+node:gcross.20110923164140.1220: *4* walkVisitorT
        ,testGroup "walkVisitorT"
            -- @+others
            -- @+node:gcross.20110923164140.1223: *5* cache step
            [testCase "cache step" $ do
                let (transformed_visitor,log) =
                        runWriter . walkVisitorT (Seq.singleton (CacheStep . encode $ (24 :: Int))) $ do
                            runAndCache (tell [1] >> return (42 :: Int) :: Writer [Int] Int)
                log @?= []
                (runWriter . runVisitorTAndGatherResults $ transformed_visitor) @?= ([24],[])
            -- @+node:gcross.20110923164140.1221: *5* choice step
            ,testCase "choice step" $ do
                let (transformed_visitor,log) =
                        runWriter . walkVisitorT (Seq.singleton (ChoiceStep True)) $ do
                            lift (tell [1])
                            (lift (tell [2]) `mplus` lift (tell [3]))
                            lift (tell [4])
                            return 42
                log @?= [1]
                (runWriter . runVisitorTAndGatherResults $ transformed_visitor) @?= ([42],[3,4])
            -- @-others
            ]
        -- @-others
        ]
    -- @-others
    -- @-<< Tests >>
    ]
-- @-leo
