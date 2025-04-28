-module(lti_example_tool_ffi).

-export([
    configure_logger_backend/0,
    exec/3
]).

configure_logger_backend() ->
    ok = logger:set_primary_config(level, info),
    ok = logger:set_handler_config(
        default,
        formatter,
        {logger_formatter, #{
            template => [level, ": ", msg, "\n"]
        }}
    ),
    ok = logger:set_application_level(stdlib, notice),
    nil.

exec(Command, Args, Cwd) ->
    Command_ = binary_to_list(Command),
    Args_ = lists:map(fun(Arg) -> binary_to_list(Arg) end, Args),
    Cwd_ = binary_to_list(Cwd),

    Name =
        case Command_ of
            "./" ++ _ -> {spawn_executable, Command_};
            "/" ++ _ -> {spawn_executable, Command_};
            _ -> {spawn_executable, os:find_executable(Command_)}
        end,

    Port = open_port(Name, [
        exit_status,
        binary,
        hide,
        stream,
        eof,
        % We need this to hide the process' stdout
        stderr_to_stdout,
        {args, Args_},
        {cd, Cwd_}
    ]),

    do_exec(Port, []).

do_exec(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            do_exec(Port, [Data | Acc]);
        {Port, {exit_status, 0}} ->
            port_close(Port),
            {ok, list_to_binary(lists:reverse(Acc))};
        {Port, {exit_status, Code}} ->
            port_close(Port),
            {error, {Code, list_to_binary(lists:reverse(Acc))}}
    end.
