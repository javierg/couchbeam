%%% -*- erlang -*-
%%%
%%% This file is part of couchbeam released under the MIT license.
%%% See the NOTICE for more information.
%%%
%%% Reference `couchbeam_replicator' target backed by an ets or dets table.
%%% It stores every replicated revision (preserving `_revisions' history),
%%% the leaf revisions per document, and the replication checkpoint.
%%%
%%% Stored entries (a `set' table):
%%%   {{doc, DocId, Rev}, {Doc, Atts}}
%%%   {{leafs, DocId}, [Rev]}
%%%   {{checkpoint, ReplId}, Seq}
%%%
%%% init/1 args is a map:
%%%   #{table => atom(),            %% table name (required)
%%%     backend => ets | dets,      %% default ets
%%%     file => string()}           %% dets file (default "<table>.dets")
%%%
%%% Note: an ets table created here is owned by the replicator process and is
%%% deleted when it stops. For a one-shot run whose results must outlive the
%%% replicator (or to resume later), create the named table yourself first
%%% (init/1 reuses an existing table) or use the dets backend.

-module(couchbeam_replicator_ets).
-behaviour(couchbeam_replicator).

%% couchbeam_replicator callbacks
-export([init/1, revs_diff/2, write_docs/2,
         read_checkpoint/2, write_checkpoint/3, terminate/2]).

%% inspection helpers (operate on a table name/ref directly)
-export([get_doc/3, leaf_revs/2, checkpoint/2]).

-record(st, {backend = ets :: ets | dets, tab :: atom()}).

%%====================================================================
%% Behaviour callbacks
%%====================================================================

init(Args) when is_map(Args) ->
    Backend = maps:get(backend, Args, ets),
    Name = maps:get(table, Args),
    case Backend of
        ets ->
            Tab = case ets:info(Name) of
                      undefined -> ets:new(Name, [named_table, public, set]);
                      _ -> Name
                  end,
            {ok, #st{backend = ets, tab = Tab}};
        dets ->
            File = maps:get(file, Args, atom_to_list(Name) ++ ".dets"),
            case dets:open_file(Name, [{file, File}, {type, set}]) of
                {ok, Tab} -> {ok, #st{backend = dets, tab = Tab}};
                {error, Reason} -> {error, Reason}
            end
    end.

revs_diff(IdRevs, #st{} = St) ->
    Missing = lists:filtermap(
        fun({DocId, Revs}) ->
            Miss = [R || R <- Revs, not has_key(St, {doc, DocId, R})],
            case Miss of
                [] -> false;
                _ -> {true, {DocId, Miss}}
            end
        end, IdRevs),
    {ok, Missing, St}.

write_docs(Entries, #st{} = St) ->
    lists:foreach(
        fun({Doc, Atts}) ->
            DocId = maps:get(<<"_id">>, Doc),
            Rev = maps:get(<<"_rev">>, Doc),
            insert(St, {doc, DocId, Rev}, {Doc, Atts}),
            Leafs = lookup(St, {leafs, DocId}, []),
            insert(St, {leafs, DocId}, lists:usort([Rev | Leafs]))
        end, Entries),
    {ok, St}.

read_checkpoint(ReplId, #st{} = St) ->
    {ok, lookup(St, {checkpoint, ReplId}, nil), St}.

write_checkpoint(ReplId, Seq, #st{} = St) ->
    insert(St, {checkpoint, ReplId}, Seq),
    {ok, St}.

terminate(_Reason, #st{backend = dets, tab = Tab}) ->
    dets:close(Tab);
terminate(_Reason, _St) ->
    ok.

%%====================================================================
%% Inspection helpers (for users/tests). `Tab' is the table name.
%%====================================================================

%% @doc Return the stored {Doc, Atts} for a revision, or undefined.
get_doc(Tab, DocId, Rev) ->
    case ets_or_dets_lookup(Tab, {doc, DocId, Rev}) of
        [{_, V}] -> V;
        [] -> undefined
    end.

%% @doc Return the leaf revisions stored for a document.
leaf_revs(Tab, DocId) ->
    case ets_or_dets_lookup(Tab, {leafs, DocId}) of
        [{_, Revs}] -> Revs;
        [] -> []
    end.

%% @doc Return the stored checkpoint sequence for a replication id, or nil.
checkpoint(Tab, ReplId) ->
    case ets_or_dets_lookup(Tab, {checkpoint, ReplId}) of
        [{_, Seq}] -> Seq;
        [] -> nil
    end.

%%====================================================================
%% Internal
%%====================================================================

insert(#st{backend = ets, tab = T}, K, V) -> ets:insert(T, {K, V});
insert(#st{backend = dets, tab = T}, K, V) -> ok = dets:insert(T, {K, V}).

lookup(St, K, Default) ->
    case do_lookup(St, K) of
        [{_, V}] -> V;
        [] -> Default
    end.

do_lookup(#st{backend = ets, tab = T}, K) -> ets:lookup(T, K);
do_lookup(#st{backend = dets, tab = T}, K) -> dets:lookup(T, K).

has_key(St, K) ->
    do_lookup(St, K) =/= [].

ets_or_dets_lookup(Tab, K) ->
    case ets:info(Tab) of
        undefined -> dets:lookup(Tab, K);
        _ -> ets:lookup(Tab, K)
    end.
