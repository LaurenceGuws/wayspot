# SDL_ReadProcess

Read all the output from a process.

## Header File

Defined in
[\<SDL3/SDL_process.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_process.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void * SDL_ReadProcess(SDL_Process *process, size_t *datasize, int *exitcode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Process](SDL_Process.html) \* | **process** | The process to read. |
| size_t \* | **datasize** | a pointer filled in with the number of bytes read, may be NULL. |
| int \* | **exitcode** | a pointer filled in with the process exit code if the process has exited, may be NULL. |

## Return Value

(void \*) Returns the data or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

If a process was created with I/O enabled, you can use this function to
read the output. This function blocks until the process is complete,
capturing all output, and providing the process exit code.

The data is allocated with a zero byte at the end (null terminated) for
convenience. This extra byte is not included in the value reported via
`datasize`.

The data should be freed with [SDL_free](SDL_free.html)().

## Thread Safety

This function is not thread safe.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateProcess](SDL_CreateProcess.html)
- [SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)
- [SDL_DestroyProcess](SDL_DestroyProcess.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProcess](CategoryProcess.html)
