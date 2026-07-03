# SDL_KillProcess

Stop a process.

## Header File

Defined in
[\<SDL3/SDL_process.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_process.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_KillProcess(SDL_Process *process, bool force);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Process](SDL_Process.html) \* | **process** | The process to stop. |
| bool | **force** | true to terminate the process immediately, false to try to stop the process gracefully. In general you should try to stop the process gracefully first as terminating a process may leave it with half-written data or in some other unstable state. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function is not thread safe.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateProcess](SDL_CreateProcess.html)
- [SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)
- [SDL_WaitProcess](SDL_WaitProcess.html)
- [SDL_DestroyProcess](SDL_DestroyProcess.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProcess](CategoryProcess.html)
