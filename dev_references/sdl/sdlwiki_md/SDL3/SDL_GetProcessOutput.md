# SDL_GetProcessOutput

Get the [SDL_IOStream](SDL_IOStream.html) associated with process
standard output.

## Header File

Defined in
[\<SDL3/SDL_process.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_process.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_IOStream * SDL_GetProcessOutput(SDL_Process *process);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Process](SDL_Process.html) \* | **process** | The process to get the output stream for. |

## Return Value

([SDL_IOStream](SDL_IOStream.html) \*) Returns the output stream or NULL
on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

The process must have been created with
[SDL_CreateProcess](SDL_CreateProcess.html)() and pipe_stdio set to
true, or with
[SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)()
and
[`SDL_PROP_PROCESS_CREATE_STDOUT_NUMBER`](SDL_PROP_PROCESS_CREATE_STDOUT_NUMBER.html)
set to [`SDL_PROCESS_STDIO_APP`](SDL_PROCESS_STDIO_APP.html).

Reading from this stream can return 0 with
[SDL_GetIOStatus](SDL_GetIOStatus.html)() returning
[SDL_IO_STATUS_NOT_READY](SDL_IO_STATUS_NOT_READY.html) if no output is
available yet.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateProcess](SDL_CreateProcess.html)
- [SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)
- [SDL_GetProcessInput](SDL_GetProcessInput.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProcess](CategoryProcess.html)
