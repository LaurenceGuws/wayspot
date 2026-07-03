# SDL_AppInit_func

Function pointer typedef for [SDL_AppInit](SDL_AppInit.html).

## Header File

Defined in
[\<SDL3/SDL_init.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_init.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef SDL_AppResult (SDLCALL *SDL_AppInit_func)(void **appstate, int argc, char *argv[]);
```

</div>

## Function Parameters

|  |  |
|----|----|
| **appstate** | a place where the app can optionally store a pointer for future use. |
| **argc** | the standard ANSI C main's argc; number of elements in `argv`. |
| **argv** | the standard ANSI C main's argv; array of command line arguments. |

## Return Value

Returns [SDL_APP_FAILURE](SDL_APP_FAILURE.html) to terminate with an
error, [SDL_APP_SUCCESS](SDL_APP_SUCCESS.html) to terminate with
success, [SDL_APP_CONTINUE](SDL_APP_CONTINUE.html) to continue.

## Remarks

These are used by
[SDL_EnterAppMainCallbacks](SDL_EnterAppMainCallbacks.html). This
mechanism operates behind the scenes for apps using the optional main
callbacks. Apps that want to use this should just implement
[SDL_AppInit](SDL_AppInit.html) directly.

## Version

This datatype is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryInit](CategoryInit.html)
