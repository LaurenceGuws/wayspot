# SDL_ProcessIO

Description of where standard I/O should be directed when creating a
process.

## Header File

Defined in
[\<SDL3/SDL_process.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_process.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_ProcessIO
{
    SDL_PROCESS_STDIO_INHERITED,    /**< The I/O stream is inherited from the application. */
    SDL_PROCESS_STDIO_NULL,         /**< The I/O stream is ignored. */
    SDL_PROCESS_STDIO_APP,          /**< The I/O stream is connected to a new SDL_IOStream that the application can read or write */
    SDL_PROCESS_STDIO_REDIRECT      /**< The I/O stream is redirected to an existing SDL_IOStream. */
} SDL_ProcessIO;
```

</div>

## Remarks

If a standard I/O stream is set to
[SDL_PROCESS_STDIO_INHERITED](SDL_PROCESS_STDIO_INHERITED.html), it will
go to the same place as the application's I/O stream. This is the
default for standard output and standard error.

If a standard I/O stream is set to
[SDL_PROCESS_STDIO_NULL](SDL_PROCESS_STDIO_NULL.html), it is connected
to `NUL:` on Windows and `/dev/null` on POSIX systems. This is the
default for standard input.

If a standard I/O stream is set to
[SDL_PROCESS_STDIO_APP](SDL_PROCESS_STDIO_APP.html), it is connected to
a new [SDL_IOStream](SDL_IOStream.html) that is available to the
application. Standard input will be available as
[`SDL_PROP_PROCESS_STDIN_POINTER`](SDL_PROP_PROCESS_STDIN_POINTER.html)
and allows [SDL_GetProcessInput](SDL_GetProcessInput.html)(), standard
output will be available as
[`SDL_PROP_PROCESS_STDOUT_POINTER`](SDL_PROP_PROCESS_STDOUT_POINTER.html)
and allows [SDL_ReadProcess](SDL_ReadProcess.html)() and
[SDL_GetProcessOutput](SDL_GetProcessOutput.html)(), and standard error
will be available as
[`SDL_PROP_PROCESS_STDERR_POINTER`](SDL_PROP_PROCESS_STDERR_POINTER.html)
in the properties for the created process.

If a standard I/O stream is set to
[SDL_PROCESS_STDIO_REDIRECT](SDL_PROCESS_STDIO_REDIRECT.html), it is
connected to an existing [SDL_IOStream](SDL_IOStream.html) provided by
the application. Standard input is provided using
[`SDL_PROP_PROCESS_CREATE_STDIN_POINTER`](SDL_PROP_PROCESS_CREATE_STDIN_POINTER.html),
standard output is provided using
[`SDL_PROP_PROCESS_CREATE_STDOUT_POINTER`](SDL_PROP_PROCESS_CREATE_STDOUT_POINTER.html),
and standard error is provided using
[`SDL_PROP_PROCESS_CREATE_STDERR_POINTER`](SDL_PROP_PROCESS_CREATE_STDERR_POINTER.html)
in the creation properties. These existing streams should be closed by
the application once the new process is created.

In order to use an [SDL_IOStream](SDL_IOStream.html) with
[SDL_PROCESS_STDIO_REDIRECT](SDL_PROCESS_STDIO_REDIRECT.html), it must
have
[`SDL_PROP_IOSTREAM_WINDOWS_HANDLE_POINTER`](SDL_PROP_IOSTREAM_WINDOWS_HANDLE_POINTER.html)
or
[`SDL_PROP_IOSTREAM_FILE_DESCRIPTOR_NUMBER`](SDL_PROP_IOSTREAM_FILE_DESCRIPTOR_NUMBER.html)
set. This is true for streams representing files and process I/O.

## Version

This enum is available since SDL 3.2.0.

## See Also

- [SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)
- [SDL_GetProcessProperties](SDL_GetProcessProperties.html)
- [SDL_ReadProcess](SDL_ReadProcess.html)
- [SDL_GetProcessInput](SDL_GetProcessInput.html)
- [SDL_GetProcessOutput](SDL_GetProcessOutput.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html),
[CategoryProcess](CategoryProcess.html)
