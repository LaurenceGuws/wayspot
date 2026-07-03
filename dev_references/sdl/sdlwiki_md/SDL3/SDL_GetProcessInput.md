# SDL_GetProcessInput

Get the [SDL_IOStream](SDL_IOStream.html) associated with process
standard input.

## Header File

Defined in
[\<SDL3/SDL_process.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_process.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_IOStream * SDL_GetProcessInput(SDL_Process *process);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Process](SDL_Process.html) \* | **process** | The process to get the input stream for. |

## Return Value

([SDL_IOStream](SDL_IOStream.html) \*) Returns the input stream or NULL
on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

The process must have been created with
[SDL_CreateProcess](SDL_CreateProcess.html)() and pipe_stdio set to
true, or with
[SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)()
and
[`SDL_PROP_PROCESS_CREATE_STDIN_NUMBER`](SDL_PROP_PROCESS_CREATE_STDIN_NUMBER.html)
set to [`SDL_PROCESS_STDIO_APP`](SDL_PROCESS_STDIO_APP.html).

Writing to this stream can return less data than expected if the process
hasn't read its input. It may be blocked waiting for its output to be
read, if so you may need to call
[SDL_GetProcessOutput](SDL_GetProcessOutput.html)() and read the output
in parallel with writing input.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateProcess](SDL_CreateProcess.html)
- [SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)
- [SDL_GetProcessOutput](SDL_GetProcessOutput.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProcess](CategoryProcess.html)
