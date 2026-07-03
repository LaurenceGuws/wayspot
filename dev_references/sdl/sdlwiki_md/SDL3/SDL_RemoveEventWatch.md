# SDL_RemoveEventWatch

Remove an event watch callback added with
[SDL_AddEventWatch](SDL_AddEventWatch.html)().

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_RemoveEventWatch(SDL_EventFilter filter, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_EventFilter](SDL_EventFilter.html) | **filter** | the function originally passed to [SDL_AddEventWatch](SDL_AddEventWatch.html)(). |
| void \* | **userdata** | the pointer originally passed to [SDL_AddEventWatch](SDL_AddEventWatch.html)(). |

## Remarks

This function takes the same input as
[SDL_AddEventWatch](SDL_AddEventWatch.html)() to identify and delete the
corresponding callback.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AddEventWatch](SDL_AddEventWatch.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEvents](CategoryEvents.html)
