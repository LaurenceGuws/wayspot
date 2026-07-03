# SDL_MAIN_USE_CALLBACKS

Inform SDL to use the main callbacks instead of main.

## Header File

Defined in
[\<SDL3/SDL_main.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_main.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_MAIN_USE_CALLBACKS 1
```

</div>

## Remarks

SDL does not define this macro, but will check if it is defined when
including `SDL_main.h`. If defined, SDL will expect the app to provide
several functions: [SDL_AppInit](SDL_AppInit.html),
[SDL_AppEvent](SDL_AppEvent.html),
[SDL_AppIterate](SDL_AppIterate.html), and
[SDL_AppQuit](SDL_AppQuit.html). The app should not provide a `main`
function in this case, and doing so will likely cause the build to fail.

Please see [README-main-functions](README-main-functions.html), (or
docs/README-main-functions.md in the source tree) for a more detailed
explanation.

## Version

This macro is used by the headers since SDL 3.2.0.

## See Also

- [SDL_AppInit](SDL_AppInit.html)
- [SDL_AppEvent](SDL_AppEvent.html)
- [SDL_AppIterate](SDL_AppIterate.html)
- [SDL_AppQuit](SDL_AppQuit.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryMain](CategoryMain.html)
