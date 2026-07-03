# SDL_FilterEvents

Run a specific filter function on the current event queue, removing any
events for which the filter returns false.

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_FilterEvents(SDL_EventFilter filter, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_EventFilter](SDL_EventFilter.html) | **filter** | the [SDL_EventFilter](SDL_EventFilter.html) function to call when an event happens. |
| void \* | **userdata** | a pointer that is passed to `filter`. |

## Remarks

See [SDL_SetEventFilter](SDL_SetEventFilter.html)() for more
information. Unlike [SDL_SetEventFilter](SDL_SetEventFilter.html)(),
this function does not change the filter permanently, it only uses the
supplied filter until this function returns.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetEventFilter](SDL_GetEventFilter.html)
- [SDL_SetEventFilter](SDL_SetEventFilter.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEvents](CategoryEvents.html)
