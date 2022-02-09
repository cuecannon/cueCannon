module Client exposing
    ( Model
    , Msg(..)
    , PlatformCmd(..)
    , PlatformResponse(..)
    , doNothing
    , initialModel
    , update
    , view
    )

import Actor
import Casting exposing (..)
import Dict exposing (Dict)
import Director
import Html.Styled as Html exposing (..)
import Interface exposing (appScaffolding, debuggingPage, genericPage, loadingPage)
import List.Extra as List
import TestScript exposing (testScript)



--  ____  _       _    __
-- |  _ \| | __ _| |_ / _| ___  _ __ _ __ ___
-- | |_) | |/ _` | __| |_ / _ \| '__| '_ ` _ \
-- |  __/| | (_| | |_|  _| (_) | |  | | | | | |
-- |_|   |_|\__,_|\__|_|  \___/|_|  |_| |_| |_|
--
--     _             _     _ _            _
--    / \   _ __ ___| |__ (_) |_ ___  ___| |_ _   _ _ __ ___
--   / _ \ | '__/ __| '_ \| | __/ _ \/ __| __| | | | '__/ _ \
--  / ___ \| | | (__| | | | | ||  __/ (__| |_| |_| | | |  __/
-- /_/   \_\_|  \___|_| |_|_|\__\___|\___|\__|\__,_|_|  \___|
--
-- Our design extends/abuses the Elm Architecture to generalize
-- backends for our app. We call these "Platforms" in a nod to
-- the Roc Language. All platforms talk to our app through the
-- "PlatformCmd" and "PlatformResponse" types. We export view, update,
-- and init so the platform Elm App can add them to its own TEA.
--
-- Working platforms:
-- Lamdera
--
-- Planned platforms:
-- Libp2p / ionic
-- IHP (ionic?)
-- Tauri?


type alias Model =
    { menuOpen : Bool
    , state : State
    , logs : List String
    , viewLogs : Bool
    }


type State
    = InitialLoading
    | Testing Int
    | Spectating
    | Director Director.Model
    | Actor Actor.Model


type Msg
    = NoOp
    | ToggleMenu
    | ToggleDebug
    | ActorMsg Actor.Msg
    | DirectorMsg Director.Msg
    | AdvanceInterfaceTestCase
    | OnlyPlatformResponse PlatformResponse
    | ClickedResetProductions


type PlatformResponse
    = NoResponse
    | ReportErrors (List String)
    | JoinedAsSpectator
    | ActorPR Actor.PlatformResponse
    | DirectorPR Director.PlatformResponse


type PlatformCmd
    = NoCmd
    | ClientInit
    | ResetProductions
    | ActorPC Actor.PlatformCmd
    | DirectorPC Director.PlatformCmd


initialModel : Model
initialModel =
    -- initialModel = Testing 0
    -- To test, replace below with above
    { menuOpen = False
    , state = InitialLoading
    , logs = [ "Initial client log entry." ]
    , viewLogs = False
    }


update : Msg -> Model -> ( Model, PlatformCmd )
update msg model =
    let
        stateToModel state =
            { model | state = state }
    in
    case ( msg, model.state ) of
        ( ActorMsg subMsg, Actor subModel ) ->
            Actor.update subMsg subModel
                |> Tuple.mapFirst Actor
                |> Tuple.mapFirst stateToModel
                |> Tuple.mapSecond ActorPC

        ( DirectorMsg subMsg, Director subModel ) ->
            Director.update subMsg subModel
                |> Tuple.mapFirst Director
                |> Tuple.mapFirst stateToModel
                |> Tuple.mapSecond DirectorPC

        ( AdvanceInterfaceTestCase, Testing i ) ->
            let
                newIndex =
                    modBy (List.length interfaceTestCases) (i + 1)
            in
            ( Testing newIndex, NoCmd )
                |> Tuple.mapFirst stateToModel

        ( OnlyPlatformResponse response, m ) ->
            updateFromPlatform response model

        ( ToggleMenu, _ ) ->
            ( { model | menuOpen = not model.menuOpen }, NoCmd )

        ( ToggleDebug, _ ) ->
            ( { model | viewLogs = not model.viewLogs }, NoCmd )

        ( ClickedResetProductions, _ ) ->
            ( model, ResetProductions )

        ( _, _ ) ->
            ( model, NoCmd )


updateFromPlatform : PlatformResponse -> Model -> ( Model, PlatformCmd )
updateFromPlatform response model =
    let
        stateToModel state =
            { model | state = state }
    in
    case ( response, model.state ) of
        -- Update
        ( ActorPR subResponse, Actor subModel ) ->
            Actor.updateFromPlatform subResponse subModel
                |> Tuple.mapFirst Actor
                |> Tuple.mapFirst stateToModel
                |> Tuple.mapSecond ActorPC

        ( DirectorPR subResponse, Director subModel ) ->
            Director.updateFromPlatform subResponse subModel
                |> Tuple.mapFirst Director
                |> Tuple.mapFirst stateToModel
                |> Tuple.mapSecond DirectorPC

        -- Init
        ( ActorPR subResponse, _ ) ->
            Actor.initialize subResponse
                |> Tuple.mapFirst Actor
                |> Tuple.mapFirst stateToModel
                |> Tuple.mapSecond ActorPC

        ( DirectorPR subResponse, _ ) ->
            Director.initialize subResponse
                |> Tuple.mapFirst Director
                |> Tuple.mapFirst stateToModel
                |> Tuple.mapSecond DirectorPC

        ( ReportErrors errors, _ ) ->
            ( { model | logs = errors }, NoCmd )

        ( JoinedAsSpectator, _ ) ->
            ( Spectating, NoCmd )
                |> Tuple.mapFirst stateToModel

        ( _, _ ) ->
            ( model, NoCmd )


view : Model -> Html Msg
view =
    viewHelper Nothing


viewHelper : Maybe Msg -> Model -> Html Msg
viewHelper testingMsg model =
    let
        currentPage =
            if model.viewLogs then
                debuggingPage (indexLogs model.logs)

            else
                case model.state of
                    Testing page ->
                        List.getAt page interfaceTestCases
                            |> Maybe.withDefault model
                            |> viewHelper (Just AdvanceInterfaceTestCase)

                    InitialLoading ->
                        loadingPage

                    Spectating ->
                        genericPage "Spectating (show in progress)" (Html.text "")

                    Director subModel ->
                        Director.view subModel
                            |> Html.map DirectorMsg

                    Actor subModel ->
                        Actor.view subModel
                            |> Html.map ActorMsg

        config =
            { menu = Interface.header testingMsg
            , menuOpen = model.menuOpen
            , toggleMsg = ToggleMenu
            , resetProductionsMsg = ClickedResetProductions
            , toggleDebugMsg = ToggleDebug
            }
    in
    appScaffolding config currentPage


doNothing : a -> Msg
doNothing =
    always (OnlyPlatformResponse NoResponse)


indexLogs : List String -> List String
indexLogs logs =
    let
        len =
            List.length logs
    in
    List.indexedMap
        (\i log ->
            String.fromInt (len - i)
                ++ ": "
                ++ log
        )
        logs



--  ___       _             __
-- |_ _|_ __ | |_ ___ _ __ / _| __ _  ___ ___
--  | || '_ \| __/ _ \ '__| |_ / _` |/ __/ _ \
--  | || | | | ||  __/ |  |  _| (_| | (_|  __/
-- |___|_| |_|\__\___|_|  |_|  \__,_|\___\___|
--  _____         _      ____
-- |_   _|__  ___| |_   / ___|__ _ ___  ___  ___
--   | |/ _ \/ __| __| | |   / _` / __|/ _ \/ __|
--   | |  __/\__ \ |_  | |__| (_| \__ \  __/\__ \
--   |_|\___||___/\__|  \____\__,_|___/\___||___/
-- Interface Test Cases for states that need visual testing.


interfaceTestCases : List Model
interfaceTestCases =
    [ InitialLoading ]
        ++ List.map Director Director.interfaceTestCases
        ++ List.map Actor Actor.interfaceTestCases
        |> List.map
            (\state ->
                { state = state
                , menuOpen = False
                , viewLogs = False
                , logs = []
                }
            )
