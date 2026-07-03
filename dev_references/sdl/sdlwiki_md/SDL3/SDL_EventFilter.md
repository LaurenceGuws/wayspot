# SDL_EventFilter

A function pointer used for callbacks that watch the event queue.

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef bool (SDLCALL *SDL_EventFilter)(void *userdata, SDL_Event *event);
```

</div>

## Function Parameters

|  |  |
|----|----|
| **userdata** | what was passed as `userdata` to [SDL_SetEventFilter](SDL_SetEventFilter.html)() or [SDL_AddEventWatch](SDL_AddEventWatch.html), etc. |
| **event** | the event that triggered the callback. |

## Return Value

Returns true to permit event to be added to the queue, and false to
disallow it. When used with [SDL_AddEventWatch](SDL_AddEventWatch.html),
the return value is ignored.

## Thread Safety

SDL may call this callback at any time from any thread; the application
is responsible for locking resources the callback touches that need to
be protected.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_SetEventFilter](SDL_SetEventFilter.html)
- [SDL_AddEventWatch](SDL_AddEventWatch.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryEvents](CategoryEvents.html)
