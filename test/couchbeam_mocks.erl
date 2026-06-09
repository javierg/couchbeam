%%% -*- erlang -*-
%%%
%%% Test mocking helpers for couchbeam tests
%%% Provides utilities to mock HTTP layer for unit testing without CouchDB

-module(couchbeam_mocks).

-export([setup/0, teardown/0]).
-export([expect_response/3, expect_db_response/3]).
-export([body/1]).

%% @doc Initialize meck for hackney and couchbeam_httpc
setup() ->
    %% Unload any existing mocks first
    try meck:unload(hackney) catch _:_ -> ok end,
    try meck:unload(couchbeam_httpc) catch _:_ -> ok end,

    %% Create mocks with passthrough for unmocked functions
    meck:new(hackney, [passthrough, no_link]),
    meck:new(couchbeam_httpc, [passthrough, no_link]),

    ok.

%% @doc Unload all mocks
teardown() ->
    try meck:unload(hackney) catch _:_ -> ok end,
    try meck:unload(couchbeam_httpc) catch _:_ -> ok end,
    ok.

%% @doc Set up an expectation for hackney:request
%% Matcher: fun(Method, Url, Headers, Body, Opts) -> boolean()
%% Response: {ok, Status, Headers, Ref} | {ok, Status, Headers} | {error, Reason}
expect_response(Matcher, Response, JsonBody) when is_function(Matcher, 5) ->
    meck:expect(hackney, request, fun(Method, Url, Headers, Body, Opts) ->
        case Matcher(Method, Url, Headers, Body, Opts) of
            true ->
                mock_response(Response, JsonBody);
            false ->
                meck:passthrough([Method, Url, Headers, Body, Opts])
        end
    end).

%% @doc Set up an expectation for couchbeam_httpc:db_request
%% Matcher: fun(Method, Url, Headers, Body, Opts) -> boolean()
%% Response: {ok, Status, Headers, Ref} | {ok, Status, Headers} | {error, Reason}
expect_db_response(Matcher, Response, JsonBody) when is_function(Matcher, 5) ->
    meck:expect(couchbeam_httpc, db_request,
        fun(Method, Url, Headers, Body, Opts, _Expect) ->
            case Matcher(Method, Url, Headers, Body, Opts) of
                true ->
                    mock_response(Response, JsonBody);
                false ->
                    meck:passthrough([Method, Url, Headers, Body, Opts, _Expect])
            end
        end).

%% @doc With hackney 4.x the body is returned eagerly in the response
%% tuple, so embed it directly.
mock_response({ok, Status, RespHeaders, _Ref}, JsonBody) ->
    {ok, Status, RespHeaders, body(JsonBody)};
mock_response({ok, Status, RespHeaders}, _JsonBody) ->
    {ok, Status, RespHeaders};
mock_response(Other, _JsonBody) ->
    Other.

%% @doc Encode a term (or pass a binary through) as a response body binary.
body(Body) when is_binary(Body) ->
    Body;
body(Term) ->
    couchbeam_ejson:encode(Term).
