# SDL_RemoveTimer

Remove a timer created with [SDL_AddTimer](SDL_AddTimer.html)().

## Header File

Defined in
[\<SDL3/SDL_timer.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_timer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RemoveTimer(SDL_TimerID id);
```

</div>

## Function Parameters

|                                 |        |                                |
|---------------------------------|--------|--------------------------------|
| [SDL_TimerID](SDL_TimerID.html) | **id** | the ID of the timer to remove. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AddTimer](SDL_AddTimer.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTimer](CategoryTimer.html)
