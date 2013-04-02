%%======================================================================
%%
%% Leo Commons
%%
%% Copyright (c) 2012 Rakuten, Inc.
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
%% ---------------------------------------------------------------------
%% leo_http  - Utils for HTTP/S3-API
%% @doc
%% @end
%%======================================================================
-module(leo_http).

-author('Yoshiyuki Kanno').
-author('Yosuke Hara').

-export([key/2, key/3,
         get_headers/2, get_headers/3, get_amz_headers/1,
         get_headers4cow/2, get_headers4cow/3, get_amz_headers4cow/1,
         rfc1123_date/1,web_date/1
        ]).

-include("leo_commons.hrl").
-include_lib("eunit/include/eunit.hrl").

-define(SLASH, <<"/">>).


%% @doc Retrieve a filename(KEY) from Host and Path.
%%
-spec(key(binary(), binary()) ->
             string()).
key(Host, Path) ->
    key([?S3_DEFAULT_ENDPOINT], Host, Path).

-spec(key(list(binary()), binary(), binary()) ->
             string()).
key(EndPointList, Host, Path) ->
    EndPoint = case lists:foldl(
                      fun(E, [] = Acc) ->
                              case binary:match(Host, E) of
                                  nomatch ->
                                      Acc;
                                  {_, _} ->
                                      [E|Acc]
                              end;
                         (_, Acc) ->
                              Acc
                      end, [], EndPointList) of
                   [] ->
                       [];
                   [Value|_] ->
                       Value
               end,
    key_1(EndPoint, Host, Path).


%% @doc Retrieve a filename(KEY) from Host and Path.
%% @private
key_1(EndPoint, Host, Path) ->
    Index = case EndPoint of
                [] ->
                    0;
                _ ->
                    case binary:match(Host, EndPoint) of
                        nomatch ->
                            0;
                        {Pos, _} ->
                            Pos + 1
                    end
            end,
    key_2(Index, Host, Path).


%% @doc "S3-Bucket" is equal to the host.
%% @private
key_2(0, Host, Path) ->
    case binary:match(Path, [?SLASH]) of
        nomatch ->
            <<Host/binary, ?SLASH/binary>>;
        _ ->
            [_, Top|_] = binary:split(Path, [?SLASH], [global]),

            case Top of
                Host ->
                    binary:part(Path, {1, byte_size(Path) -1});
                _ ->
                    <<Host/binary, Path/binary>>
            end
    end;

%% @doc "S3-Bucket" is included in the path
%% @private
key_2(1,_Host, ?SLASH) ->
    ?SLASH;

key_2(1,_Host, Path) ->
    case binary:match(Path, [?SLASH]) of
        nomatch ->
            ?SLASH;
        _ ->
            binary:part(Path, {1, byte_size(Path) -1})
    end;

%% @doc "S3-Bucket" is included in the host
%% @private
key_2(Index, Host, Path) ->
    Bucket = binary:part(Host, {0, Index -2}),
    <<Bucket/binary, Path/binary>>.



%% @doc Retrieve AMZ-S3-related headers
%%      assume that TreeHeaders is generated by mochiweb_header
%%
-spec(get_headers(list(), function()) ->
             list()).
get_headers(TreeHeaders, FilterFun) when is_function(FilterFun) ->
    Iter = gb_trees:iterator(TreeHeaders),
    get_headers(Iter, FilterFun, []).
get_headers(Iter, FilterFun, Acc) ->
    case gb_trees:next(Iter) of
        none ->
            Acc;
        {Key, Val, Iter2} ->
            case FilterFun(Key) of
                true ->  get_headers(Iter2, FilterFun, [Val|Acc]);
                false -> get_headers(Iter2, FilterFun, Acc)
            end
    end.

get_headers4cow(Headers, FilterFun) when is_function(FilterFun) ->
    get_headers4cow(Headers, FilterFun, []).

get_headers4cow([], _FilterFun, Acc) ->
    Acc;
get_headers4cow([{K, V}|Rest], FilterFun, Acc) when is_binary(K) ->
    case FilterFun(K) of
        true ->  get_headers4cow(Rest, FilterFun, [{binary_to_list(K), binary_to_list(V)}|Acc]);
        false -> get_headers4cow(Rest, FilterFun, Acc)
    end;
get_headers4cow([_|Rest], FilterFun, Acc) ->
    get_headers4cow(Rest, FilterFun, Acc).

%% @doc Retrieve AMZ-S3-related headers
%%
-spec(get_amz_headers(list()) ->
             list()).
get_amz_headers(TreeHeaders) ->
    get_headers(TreeHeaders, fun is_amz_header/1).

get_amz_headers4cow(ListHeaders) ->
    get_headers4cow(ListHeaders, fun is_amz_header/1).

%% @doc Retrieve RFC-1123 formated data
%%
-spec(rfc1123_date(integer()) ->
             string()).
rfc1123_date(DateSec) ->
    %% NOTE:
    %%   Don't use http_util:rfc1123 on R14B*.
    %%   In this func, There is no error handling for `local_time_to_universe`
    %%   So badmatch could occur. This result in invoking huge context switched.
    {{Y,M,D},{H,MI,S}} = calendar:gregorian_seconds_to_datetime(DateSec),
    Mon = month(M),
    W = weekday(Y,M,D),
    lists:flatten(io_lib:format("~3s, ~2.10.0B ~3s ~4.10B ~2.10.0B:~2.10.0B:~2.10.0B GMT", [W, D, Mon, Y, H, MI, S])).

weekday(Y, M, D) ->
    weekday(calendar:day_of_the_week(Y, M, D)).

weekday(1) -> "Mon";
weekday(2) -> "Tue";
weekday(3) -> "Wed";
weekday(4) -> "Thu";
weekday(5) -> "Fri";
weekday(6) -> "Sat";
weekday(7) -> "Sun".

month( 1) -> "Jan";
month( 2) -> "Feb";
month( 3) -> "Mar";
month( 4) -> "Apr";
month( 5) -> "May";
month( 6) -> "Jun";
month( 7) -> "Jul";
month( 8) -> "Aug";
month( 9) -> "Sep";
month(10) -> "Oct";
month(11) -> "Nov";
month(12) -> "Dec".

%% @doc Convert gregorian seconds to date formated data( YYYY-MM-DDTHH:MI:SS000Z )
%%
-spec(web_date(integer()) ->
             string()).
web_date(GregSec) when is_integer(GregSec) ->
    {{Y,M,D},{H,MI,S}} = calendar:gregorian_seconds_to_datetime(GregSec),
    lists:flatten(io_lib:format("~4.10.0B-~2.10.0B-~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0B.000Z",[Y,M,D,H,MI,S])).

%%--------------------------------------------------------------------
%%% INTERNAL FUNCTIONS
%%--------------------------------------------------------------------
%% @doc Is it AMZ-S3's header?
%% @private
-spec(is_amz_header(string()|binary()) ->
             boolean()).
is_amz_header(<<"x-amz-", _Rest/binary>>) -> true;
is_amz_header(<<"X-Amz-", _Rest/binary>>) -> true;
is_amz_header(Key) when is_binary(Key) ->
    false;
is_amz_header(Key) ->
    (string:str(string:to_lower(Key), "x-amz-") == 1).

