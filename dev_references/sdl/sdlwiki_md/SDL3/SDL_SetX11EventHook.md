# SDL_SetX11EventHook

Set a callback for every X11 event.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetX11EventHook(SDL_X11EventHook callback, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_X11EventHook](SDL_X11EventHook.html) | **callback** | the [SDL_X11EventHook](SDL_X11EventHook.html) function to call. |
| void \* | **userdata** | a pointer to pass to every iteration of `callback`. |

## Remarks

The callback may modify the event, and should return true if the event
should continue to be processed, or false to prevent further processing.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
