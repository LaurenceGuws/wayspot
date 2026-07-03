# CategoryMain

Redefine main() if necessary so that it is called by SDL.

In order to make this consistent on all platforms, the application's
main() should look like this:

<div id="cb1" class="sourceCode">

``` sourceCode
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

int main(int argc, char *argv[])
{
}
```

</div>

SDL will take care of platform specific details on how it gets called.

This is also where an app can be configured to use the main callbacks,
via the [SDL_MAIN_USE_CALLBACKS](SDL_MAIN_USE_CALLBACKS.html) macro.

[SDL_main](SDL_main.html).h is a "single-header library," which is to
say that including this header inserts code into your program, and you
should only include it once in most cases. SDL.h does not include this
header automatically.

For more information, see:

[https://wiki.libsdl.org/SDL3/README-main-functions](README-main-functions.html)

## Functions

- [SDL_AppEvent](SDL_AppEvent.html)
- [SDL_AppInit](SDL_AppInit.html)
- [SDL_AppIterate](SDL_AppIterate.html)
- [SDL_AppQuit](SDL_AppQuit.html)
- [SDL_EnterAppMainCallbacks](SDL_EnterAppMainCallbacks.html)
- [SDL_GDKSuspendComplete](SDL_GDKSuspendComplete.html)
- [SDL_main](SDL_main.html)
- [SDL_RegisterApp](SDL_RegisterApp.html)
- [SDL_RunApp](SDL_RunApp.html)
- [SDL_SetMainReady](SDL_SetMainReady.html)
- [SDL_UnregisterApp](SDL_UnregisterApp.html)

## Datatypes

- [SDL_main_func](SDL_main_func.html)

## Structs

- (none.)

## Enums

- (none.)

## Macros

- [SDL_MAIN_AVAILABLE](SDL_MAIN_AVAILABLE.html)
- [SDL_MAIN_HANDLED](SDL_MAIN_HANDLED.html)
- [SDL_MAIN_NEEDED](SDL_MAIN_NEEDED.html)
- [SDL_MAIN_USE_CALLBACKS](SDL_MAIN_USE_CALLBACKS.html)
- [SDLMAIN_DECLSPEC](SDLMAIN_DECLSPEC.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
