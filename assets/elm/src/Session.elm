module Session exposing (Session, Error(..), Payload, init, decodeToken, fetchNewToken, request)

import Http
import Json.Decode as Decode exposing (field)
import Json.Decode.Pipeline as Pipeline
import Jwt exposing (JwtError)
import Task exposing (Task, succeed, fail)
import Time exposing (Time)


type alias Payload =
    { iat : Int
    , exp : Int
    , sub : String
    }


type alias Session =
    { token : String
    , payload : Result JwtError Payload
    }


type Error
    = Expired
    | Invalid
    | HttpError Http.Error


{-| Accepts a JWT and generates a new Session record that contains the decoded
payload.

    init "ey..." ==
        { token = "ey..."
        , payload = Ok { iat = 1517515691, exp = 1517515691, sub = "999999999" }
        }

    init "invalid" ==
        { token = "invalid"
        , payload = Err (TokenProcessingError "Wrong length")
        }

-}
init : String -> Session
init token =
    Session token (decodeToken token)


{-| Accepts a token and returns a Result from attempting to decode the payload.

    decodeToken "ey..." == Ok { iat = 1517515691, exp = 1517515691, sub = "999999999" }
    decodeToken "invalid" == Err (TokenProcessingError "Wrong length")

-}
decodeToken : String -> Result JwtError Payload
decodeToken token =
    let
        decoder =
            Pipeline.decode Payload
                |> Pipeline.required "iat" Decode.int
                |> Pipeline.required "exp" Decode.int
                |> Pipeline.required "sub" Decode.string
    in
        Jwt.decodeToken decoder token


{-| Builds a request for fetching a new JWT. This request should succeed if
there a valid cookie-based session.
-}
fetchNewToken : Session -> Task Error Session
fetchNewToken session =
    let
        request =
            Http.post "/api/tokens" Http.emptyBody <|
                Decode.map init (field "token" Decode.string)
    in
        request
            |> Http.toTask
            |> Task.mapError handleError


{-| Builds a `Task` that refreshes the `Session` if it has expired, then
executes the given request with that session.
-}
request : Session -> (Session -> Http.Request a) -> Task Error ( Session, a )
request session innerRequest =
    let
        refreshIfExpired : Session -> Time -> Task Error Session
        refreshIfExpired session now =
            case session.payload of
                Ok payload ->
                    if payload.exp <= round (Time.inSeconds now) then
                        fetchNewToken session
                    else
                        succeed session

                _ ->
                    fail Invalid

        performRequest : Session -> Task Error ( Session, a )
        performRequest session =
            innerRequest session
                |> Http.toTask
                |> Task.mapError handleError
                |> Task.map (\a -> ( session, a ))
    in
        Time.now
            |> Task.andThen (refreshIfExpired session)
            |> Task.andThen performRequest


handleError : Http.Error -> Error
handleError error =
    case error of
        Http.BadStatus { status } ->
            if status.code == 401 || status.code == 403 then
                Expired
            else
                HttpError error

        _ ->
            HttpError error
