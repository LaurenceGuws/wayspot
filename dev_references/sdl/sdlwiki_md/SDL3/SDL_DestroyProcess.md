# SDL_DestroyProcess

Destroy a previously created process object.

## Header File

Defined in
[\<SDL3/SDL_process.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_process.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyProcess(SDL_Process *process);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Process](SDL_Process.html) \* | **process** | The process object to destroy. |

## Remarks

Note that this does not stop the process, just destroys the SDL object
used to track it. If you want to stop the process you should use
[SDL_KillProcess](SDL_KillProcess.html)().

## Thread Safety

This function is not thread safe.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateProcess](SDL_CreateProcess.html)
- [SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)
- [SDL_KillProcess](SDL_KillProcess.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProcess](CategoryProcess.html)
