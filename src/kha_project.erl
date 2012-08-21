%%% @author Paul Peter Flis <pawel@flycode.pl>
%%% @copyright (C) 2012, Green Elephant Labs
%%% @doc
%%% kha_project module
%%% @end
%%% Created : 31 Jul 2012 by Paul Peter Flis <pawel@flycode.pl>

-module(kha_project).

-include("kha.hrl").

-export([create/1,
         get/1,
         update/1]).

-export([create_fake/0]).

create(Project) ->
    {ok, Response} = db:transaction(fun() -> do_create(Project) end),
    Response.

do_create(Project) ->
    ProjectId = db:get_next_id(project),
    R = Project#project{id = ProjectId},
    ok = db:add_record(R),
    {ok, R}.

get(all) ->
    db:get_match_object(#project{_='_'});

get(Id) ->
    {ok, Response} = db:transaction(fun() -> do_get(Id) end),
    Response.

do_get(Id) ->
    db:get_record(project, Id).

update(Project) ->
    db:add_record(Project).

%% ONLY FOR DEBUG !!!
create_fake() ->
    R = [#project{name   = <<"kha test project">>,
                  local  = <<"/tmp/test_build">>,
                  remote = <<"https://github.com/greenelephantlabs/kha.git">>,
                  build  = [<<"rebar get-deps">>, <<"make">>],
                  params = [{build_timeout, 60}],
                  notifications = []},
         #project{name   = <<"Oortle">>,
                  local  = <<"/tmp/oortle_build">>,
                  remote = <<"git@github.com:LivePress/oortle.git">>,
                  build  = [<<"./oortle/compile-and-run-tests.sh">>],
                  params = [{build_timeout, 600}], %% 10 min
                  notifications = []}
         ],
    [ begin
          {ok, Project} = kha_project:create(X),
          PId = Project#project.id,
          ?LOG("Create fake project - ID: ~b", [PId])
      end || X <- R ].
    %% [ kha_build:create(PId, X) || X <- example_builds() ].

%% example_builds() ->
%%     [#build{title    = "Test 1",
%%             branch   = "origin/master",
%%             author   = "Paul Peter Flis",
%%             tags     = ["paul", "peter", "test_branch_1"]
%%            },
%%      #build{title    = "Test 2",
%%             branch   = "test_branch_1",
%%             author   = "Gleb Peregud",
%%             tags     = ["gleber", "peregud", "test_branch_1"]
%%            },
%%      #build{title    = "Test 3",
%%             branch   = "test_branch_2",
%%             author   = "Paul Peregud",
%%             tags     = ["paul", "peregud", "test_branch_2"]
%%            }
%%     ].
