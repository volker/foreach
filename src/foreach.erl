-module (foreach).

-export ([main/1]).

main([]) ->
	usage();
main(Args) ->
	{_, BeforeSecs, _} = os:timestamp(),

	{ok, [{{default, Default}, FolderSets}]} = file:consult(".foreach"),
	ParsedArgs = parse_args(Args, [{set, Default}, {workers, "10"}, {cmd, []}]),
	{ok, Folders} = select_set(element(2, lists:keyfind(set, 1, ParsedArgs)), FolderSets),
	Command = string:join(element(2, lists:keyfind(cmd, 1, ParsedArgs)), " "),
	Num = list_to_integer(element(2, lists:keyfind(workers, 1, ParsedArgs))),
	if Num < 1 -> command_and_collect(1, Command, Folders, []);
		Num > length(Folders) -> command_and_collect(length(Folders), Command, Folders, []);
		true -> command_and_collect(Num, Command, Folders, [])
	end,

	{_, AfterSecs, _} = os:timestamp(),
	Duration = AfterSecs - BeforeSecs,
	case Duration of
			0 -> io:format("done.~n");
			_ -> io:format("done (~p secs).~n", [Duration])
		end.


parse_args([], Acc) ->
	Acc;
parse_args(["-s" | [Set | Args]], Acc) ->
	parse_args(Args, lists:keystore(set, 1, Acc, {set, Set}));
parse_args(["-n" | [Num | Args]], Acc) ->
	parse_args(Args, lists:keystore(workers, 1, Acc, {workers, Num}));
parse_args(Cmd, Acc) ->
	parse_args([], lists:keystore(cmd, 1, Acc, {cmd, Cmd})).


usage() ->
	io:format("usage: [-s <Set>] [-n <Number of workers>] command [command]+.~n"),
	halt(1).


select_set(_, []) ->
	{error};
select_set(Default, [{Default, Folders} | _]) ->
	{ok, Folders};
select_set(Default, [{_, _} | T]) ->
	select_set(Default, T).


worker() ->
	receive
		{Pid, F, Command} ->
			{_, BeforeSecs, _} = os:timestamp(),
			Result = [os:cmd(string:join(["cd", F, "&&", Command], " "))],
			{_, AfterSecs, _} = os:timestamp(),
			Pid ! {self(), ok, F, Command, Result, AfterSecs - BeforeSecs},
			worker();
		kill ->
			ok
	end.


command_and_collect(_, _, [], []) ->
	ok;
command_and_collect(N, C, Folders, []) ->
	{F0, F1} = lists:split(N, Folders),
	Workers = lists:foldl(
			fun(F, Workers) ->
				Worker = spawn(fun() -> worker() end),
				Worker ! {self(), F, C},
				[Worker | Workers]
			end,
		[], F0),
	command_and_collect(N, C, F1, Workers);
command_and_collect(N, C, [], Workers) ->
	receive
		{Worker, ok, Folder, Command, Result, Duration} ->
			format_result(Folder, Command, Result, Duration),
			Worker ! kill,
			command_and_collect(N, C, [], lists:delete(Worker, Workers))
	end;
command_and_collect(N, C, [F | Folders], Workers) ->
	receive
		{Worker, ok, Folder, Command, Result, Duration} ->
			format_result(Folder, Command, Result, Duration),
			Worker ! {self(), F, C},
			command_and_collect(N, C, Folders, Workers)
	end.


format_result(Folder, Command, Result, 0) ->
	ok = io:format("~s: ~s~n~ts~n", [Folder, Command, Result]);
format_result(Folder, Command, Result, Duration) ->
	ok = io:format("~s: ~s (~p secs)~n~ts~n", [Folder, Command, Duration, Result]).
