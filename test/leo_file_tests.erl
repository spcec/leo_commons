%%====================================================================
%%
%% Leo Commons
%%
%% Copyright (c) 2012-2015 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%%====================================================================
-module(leo_file_tests).
-author('Yosuke Hara').

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% TEST
%%--------------------------------------------------------------------
-ifdef(EUNIT).
-define(TEST_FILE_1, "test.dat.1").
-define(TEST_FILE_2, "test.dat.2").

%% TEST-1
pread_1_test_() ->
    [
     fun() ->
             os:cmd("rm " ++ ?TEST_FILE_1),

             {ok, IoDevice} = file:open(?TEST_FILE_1, [raw, read, write, binary, append]),
             ok = file:pwrite(IoDevice, 0, crypto:rand_bytes(128)),

             {ok,_Bin_1} = leo_file:pread(IoDevice, 1, 32),
             {ok,_Bin_2} = leo_file:pread(IoDevice, 64, 64),
             {ok,_Bin_3} = leo_file:pread(IoDevice, 1,  64, true, 5),

             {error, unexpected_len} = leo_file:pread(IoDevice, 96, 64, true, 5),
             eof = leo_file:pread(IoDevice, 129, 32, true, 5),

             ok = file:close(IoDevice),
             ok
     end
    ].


%% TEST-2
pread_2_test_() ->
    {setup,
     fun ( ) ->
             ok
     end,
     fun (_) ->
             ok
     end,
     [
      {"test file_pread",
       {timeout, 1000, fun pread_2/0}}
     ]}.

pread_2() ->
    %% Remove and create a file
    SizeToRead = 1024 * 1024 * 10,
    NumReadOp = 3,
    Concurrency = 3,

    os:cmd("rm " ++ ?TEST_FILE_2),
    {ok, IoDevice} = file:open(?TEST_FILE_2, [raw, read, write, binary, append]),
    ok = file:pwrite(IoDevice, 0, crypto:rand_bytes(SizeToRead)),
    ok = file:close(IoDevice),
    timer:sleep(200),

    %% Launch test processes
    [spawn(fun() ->
                   run(SizeToRead, NumReadOp, 0)
           end)
     || _ <- lists:seq(1, Concurrency)],
    timer:sleep(timer:seconds(3)),
    ok.


%%--------------------------------------------------------------------
%% Internal Functions
%%--------------------------------------------------------------------
%% @private
run(SizeToRead, NumReadOp, 0) ->
    {ok, Dev} = file:open(?TEST_FILE_2, [read, raw, binary]),
    run(Dev, filelib:file_size(?TEST_FILE_2), SizeToRead, NumReadOp, 0).

run(Dev,_MaxPos,_SizeToRead, NumReadOp, NumReadOp) ->
    file:close(Dev),
    ok;
run(Dev, MaxPos, SizeToRead, NumReadOp, CurNum) ->
    Pos = random:uniform(MaxPos - 1),
    {error,unexpected_len} = leo_file:pread(Dev, Pos, SizeToRead, true, 5),
    run(Dev, MaxPos, SizeToRead, NumReadOp, CurNum + 1).

-endif.