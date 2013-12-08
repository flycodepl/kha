%%% @author Paul Peter Flis <pawel@flycode.pl>
%%% @copyright (C) 2012, Green Elephant Labs
%%% @doc
%%% kha_build module
%%% @end
%%% Created : 31 Jul 2012 by Paul Peter Flis <pawel@flycode.pl>

-module(kha_build).

-include("common.hrl").
-include("kha.hrl").

-export([create/2,
         create_and_add_to_queue/6,

         get/2,
         get_by_revision/1,

         get_rev/1,

         check_by_revision/1,

         delete/1,
         delete/2,

         update/1,
         update_revision/3,
         update_revision/1,

         upgrade/0, upgrade/1]).

create(ProjectId, Build) ->
    {ok, Response} = db:transaction(fun() -> do_create(ProjectId, Build) end),
    Response.

do_create(ProjectId, Build) ->
    BuildId = db:get_next_id({build, ProjectId}),
    R = Build#build{key = {ProjectId, BuildId},
                    id          = BuildId,
                    project     = ProjectId,
                    create_time = now(),
                    status      = 'pending',
                    exit        = -1, %% FIXME: PF: Should by 'undefined'
                    output      = []},
    ok = db:add_record(R),
    {ok, R}.

create_and_add_to_queue(ProjectId, Title, Branch, Revision, Author, Tags) ->
    New = #build{title    = Title,
                 branch   = Branch,
                 revision = Revision,
                 author   = Author,
                 tags     = Tags},
    {ok, Build} = kha_build:create(ProjectId, New),
    kha_builder:add_to_queue(Build),
    {ok, Build}.


get_limit(T,D,Id,C) ->
    lists:flatten(get_limit(T,D,mnesia:D(T,Id),C, [])). %% we need to skip first entry

get_limit(_T,_D,'$end_of_table', _C, A) ->
    A;
get_limit(_T,_D, _, C, A) when C =< 0 ->
    A;
get_limit(T, D, {PId, _} = Current, C, A) ->
    R = mnesia:read(T, Current),
    case mnesia:D(T, Current) of
        {PId, _} = Return ->
            get_limit(T, D, Return, C-length(R), [R|A]);
        _ ->
            [R|A]
    end.

get_by_revision(Revision) ->
    db:get_record_by_index(build, Revision, #build.revision).

get_rev(#build{} = Build) ->
    Branch = kha_utils:convert(Build#build.branch, str),
    Revision = kha_utils:convert(Build#build.revision, str),
    case Revision of
        undefined -> Branch;
        "" -> Branch;
        _ -> Revision
    end.

get(ProjectId, {prev, Count}) ->
    get(ProjectId, {prev, undefined, Count});
get(ProjectId, {prev, BuildId, Count}) ->
    db:transaction(fun() ->
                           get_limit(build, prev, {ProjectId, BuildId}, Count)
                   end);

get(ProjectId, all) ->
    db:get_match_object(#build{key={ProjectId, '_'}, _='_'});

get(ProjectId, BuildId) ->
    {ok, Response} = db:transaction(fun() -> do_get(ProjectId, BuildId) end),
    Response.

do_get(ProjectId, BuildId) ->
    db:get_record(build, {ProjectId, BuildId}).

%% return false if revision is new (never built)
check_by_revision(Revision) ->
    case db:get_record_by_index(revision, Revision, #revision.rev) of
        {ok, []} -> false;
        {ok, _}  -> true
    end.

delete(#build{} = Build) ->
    db:remove_object(Build).

delete(ProjectId, BuildId) ->
    db:remove_record(build, {ProjectId, BuildId}).

update_revision(Remotes) when is_list(Remotes) ->
    do_update_revision(Remotes).
do_update_revision([]) -> ok;
do_update_revision([X | R]) ->
    ?LOG("Update revision for ~s", [X]),
    Refs = git:refs(X),
    [update_revision(X, Name, Rev) || {Name, Type, Rev} <- Refs, Type /= 'HEAD' ],
    do_update_revision(R).

update_revision(Remote, BranchName, Rev) ->
    db:add_record(#revision{key = {Remote, BranchName},
                            rev = Rev}).
update(Build) ->
    db:add_record(Build).

upgrade() ->
    mnesia:transform_table(build, fun upgrade/1, record_info(fields, build)),
    {ok, Ps} = db:get_all(build),
    [ ?MODULE:update(upgrade(P)) || P <- Ps ].

%% for commit: 5e640e9c
upgrade({build,
         Xkey, Xid, Xproject, Xtitle, Xbranch, Xrevision,
         Xauthor, Xstart, Xstop, Xstatus, Xexit, Xoutput, Xtags}) ->
    #build{key = Xkey, id = Xid, project = Xproject, title = Xtitle,
           branch = Xbranch, revision = Xrevision,
           author = Xauthor, start = Xstart, stop = Xstop, status = Xstatus, exit = Xexit,
           output = Xoutput, tags = Xtags, dir = <<"/tmp/">>};

%% for commit: 81c0428b
upgrade({build,
         Xkey, Xid, Xproject, Xtitle, Xbranch, Xrevision, Xauthor,
         Xstart, Xstop, Xstatus, Xexit, Xoutput, Xtags, Xdir}) ->
    #build{key         = Xkey,
           pid_ref     = undefined,
           id          = Xid,
           project     = Xproject,
           title       = Xtitle,
           branch      = Xbranch,
           revision    = Xrevision,
           author      = Xauthor,
           create_time = Xstart,
           start       = Xstart,
           stop        = Xstop,
           status      = Xstatus,
           exit        = Xexit,
           output      = Xoutput,
           tags        = Xtags,
           dir         = Xdir};

upgrade(#build{} = B) ->
    B.
