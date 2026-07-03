# SDL_SetLinuxThreadPriority

Sets the UNIX nice value for a thread.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetLinuxThreadPriority(Sint64 threadID, int priority);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [Sint64](Sint64.html) | **threadID** | the Unix thread ID to change priority of. |
| int | **priority** | the new, Unix-specific, priority value. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This uses setpriority() if possible, and RealtimeKit if available.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
