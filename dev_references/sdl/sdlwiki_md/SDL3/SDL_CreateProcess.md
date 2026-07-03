# SDL_CreateProcess

Create a new process.

## Header File

Defined in
[\<SDL3/SDL_process.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_process.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Process * SDL_CreateProcess(const char * const *args, bool pipe_stdio);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* const \* | **args** | the path and arguments for the new process. |
| bool | **pipe_stdio** | true to create pipes to the process's standard input and from the process's standard output, false for the process to have no input and inherit the application's standard output. |

## Return Value

([SDL_Process](SDL_Process.html) \*) Returns the newly created and
running process, or NULL if the process couldn't be created.

## Remarks

The path to the executable is supplied in args\[0\]. args\[1..N\] are
additional arguments passed on the command line of the new process, and
the argument list should be terminated with a NULL, e.g.:

<div id="cb2" class="sourceCode">

``` sourceCode
const char *args[] = { "myprogram", "argument", NULL };
```

</div>

Setting pipe_stdio to true is equivalent to setting
[`SDL_PROP_PROCESS_CREATE_STDIN_NUMBER`](SDL_PROP_PROCESS_CREATE_STDIN_NUMBER.html)
and
[`SDL_PROP_PROCESS_CREATE_STDOUT_NUMBER`](SDL_PROP_PROCESS_CREATE_STDOUT_NUMBER.html)
to [`SDL_PROCESS_STDIO_APP`](SDL_PROCESS_STDIO_APP.html), and will allow
the use of [SDL_ReadProcess](SDL_ReadProcess.html)() or
[SDL_GetProcessInput](SDL_GetProcessInput.html)() and
[SDL_GetProcessOutput](SDL_GetProcessOutput.html)().

See
[SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)()
for more details.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)
- [SDL_GetProcessProperties](SDL_GetProcessProperties.html)
- [SDL_ReadProcess](SDL_ReadProcess.html)
- [SDL_GetProcessInput](SDL_GetProcessInput.html)
- [SDL_GetProcessOutput](SDL_GetProcessOutput.html)
- [SDL_KillProcess](SDL_KillProcess.html)
- [SDL_WaitProcess](SDL_WaitProcess.html)
- [SDL_DestroyProcess](SDL_DestroyProcess.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProcess](CategoryProcess.html)
