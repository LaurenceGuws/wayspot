# SDL_AppQuit_func

Function pointer typedef for [SDL_AppQuit](SDL_AppQuit.html).

## Header File

Defined in
[\<SDL3/SDL_init.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_init.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void (SDLCALL *SDL_AppQuit_func)(void *appstate, SDL_AppResult result);
```

</div>

## Function Parameters

|  |  |
|----|----|
| **appstate** | an optional pointer, provided by the app in [SDL_AppInit](SDL_AppInit.html). |
| **result** | the result code that terminated the app (success or failure). |

## Remarks

These are used by
[SDL_EnterAppMainCallbacks](SDL_EnterAppMainCallbacks.html). This
mechanism operates behind the scenes for apps using the optional main
callbacks. Apps that want to use this should just implement
[SDL_AppEvent](SDL_AppEvent.html) directly.

## Version

This datatype is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryInit](CategoryInit.html)
