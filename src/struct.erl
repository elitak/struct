%% @doc Utilities for working with mochijson2 struct.

%%  struct example : 
%% 
%%  S = {struct, [	
%% 			{<<"name">>, <<"Foo">>}, 
%% 			{<<"activity">>, {struct, [
%% 				{<<"name">>, <<"Basketball">>}
%% 				{<<"duration">>, 60},
%% 				{<<"intensity">>, 10}]}}]}
%% 
%%  get_value(<<"name">>, S)
%%  get_value({<<"activity">>, <<"duration">>}, S)
%%  set_value(<<"lastName">>, <<"Bar">>, S)
%%  set_value({<<"activity">>, <<"duration">>}, 75, S)
%%  delete(<<"name">>, S)
%%  delete({<<"activity">>, <<"duration">>}, S)  

-module(struct).

-export([extend/2, withdraw/2, get_value/2, set_value/3, delete/2]).

-define(JSON(Obj), {Obj}).

%% @type key() = binary()
%% @type value() = [integer() | float() | atom() | tuple() | binary() | string() | list()]
%% @type struct() = tuple()
%% @type path() = tuple()

%% @spec extend(struct(), list()) -> struct()
%% @doc Extend a json struct with one or more json struct (add new leaves and modify the existing ones).
extend(S1, []) ->
	S1;

extend(S1, [S|T]) ->
	NewS = extend(S1, S),
	extend(NewS, T);

extend(S1, S2) ->
	?JSON(L1) = S1,
	?JSON(L2) = S2,
	ext(L1, L2, []).

ext(L1, [], Result) ->
	?JSON(lists:append(Result,L1));

ext(L1, [{K, ?JSON(ChildL2)} | T], Result) ->
	case proplists:get_value(K, L1) of
		?JSON(ChildL1) ->
			NewL1 = proplists:delete(K, L1),
			ext(NewL1, T, [{K, extend(?JSON(ChildL1), ?JSON(ChildL2))} | Result]);
		_ ->
			NewL1 = proplists:delete(K, L1),
			 ext(NewL1, T, [{K, ?JSON(ChildL2)} | Result])
	end;

ext(L1, [{K, V} | T], Result) ->
	NewL1 = proplists:delete(K, L1),
 	ext(NewL1, T, [{K,V} | Result]).


%% @spec withdraw(struct(), structlist()) -> struct()
%% @doc withdraw acts in the exact opposite way of extend (note : you just need to specify the keys).
withdraw(S1, []) ->
	S1;
withdraw(S1, [S|T]) ->
	NewS = withdraw(S1, S),
	withdraw(NewS, T);
withdraw(S1, S2) ->
	?JSON(L1) = S1,
	?JSON(L2) = S2,
	wdr(L1, L2, []).

wdr([], _L2, Result) ->
	?JSON(Result);

wdr([{K, ?JSON(ChildL1)} | T], L2, Result) ->
	case proplists:get_value(K, L2) of
		?JSON(ChildL2) ->
			wdr(T, L2, [{K, withdraw(?JSON(ChildL1), ?JSON(ChildL2))} | Result]);
		_ ->
			case proplists:is_defined(K, L2) of 
				false ->
					wdr(T, L2, [{K, ?JSON(ChildL1)} | Result]);
				true ->
					wdr(T, L2, Result)
			end
		end;

wdr([{K, V} | T], L2, Result) ->
	case proplists:is_defined(K, L2) of
		false ->
			wdr(T, L2, [ {K, V} | Result]);
		true ->
			wdr(T, L2, Result)
		end.


%% @spec get_value(path() | key(), struct()) -> value()
% TODO fixup set_value the same way, then update spec with path() = tuple() | list()
get_value(_, undefined) ->
	undefined;
get_value(Key, ?JSON(List)) when is_binary(Key) ->
	proplists:get_value(Key, List);
get_value(Path, Struct) when is_tuple(Path) ->
	get_value(tuple_to_list(Path), Struct);
get_value([Key], Struct) ->
	get_value(Key, Struct);
get_value([Key | T], Struct) ->
	get_value(T, get_value(Key, Struct)).

%% @spec set_value(path() | key(), value(),struct()) -> struct()
set_value(Path, Value, Struct) when is_tuple(Path) ->
	[H | T] = lists:reverse(tuple_to_list(Path)),
	set_val(T, Struct, ?JSON([{H, Value}]));
set_value(Key, Value, Struct) ->
	extend(Struct, ?JSON([{Key, Value}])).

set_val([], Struct, Result) ->
	extend(Struct, Result);
set_val([Key | T], Struct, Result) ->
	set_val(T, Struct, ?JSON([{Key, Result}])).


%% @spec delete(path() | key(), struct()) -> value()
delete(Path, Struct) when is_tuple(Path) ->
	[H | T] = lists:reverse(tuple_to_list(Path)),
	del(T, Struct, ?JSON([{H}]));
delete(Key, Struct) ->
	?JSON(L) = Struct,
	?JSON(proplists:delete(Key, L)).

del([], Struct, Result) ->
	withdraw(Struct, Result);
del([Key | T ], Struct, Result) ->
	del(T, Struct, ?JSON([{Key, Result}])).


