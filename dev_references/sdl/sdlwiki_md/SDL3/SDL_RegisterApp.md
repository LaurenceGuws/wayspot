# SDL_RegisterApp

Register a win32 window class for SDL's use.

## Header File

Defined in
[\<SDL3/SDL_main.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_main.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RegisterApp(const char *name, Uint32 style, void *hInst);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **name** | the window class name, in UTF-8 encoding. If NULL, SDL currently uses "[SDL_app](SDL_app.html)" but this isn't guaranteed. |
| [Uint32](Uint32.html) | **style** | the value to use in WNDCLASSEX::style. |
| void \* | **hInst** | the HINSTANCE to use in WNDCLASSEX::hInstance. If zero, SDL will use `GetModuleHandle(NULL)` instead. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This can be called to set the application window class at startup. It is
safe to call this multiple times, as long as every call is eventually
paired with a call to [SDL_UnregisterApp](SDL_UnregisterApp.html), but a
second registration attempt while a previous registration is still
active will be ignored, other than to increment a counter.

Most applications do not need to, and should not, call this directly;
SDL will call it when initializing the video subsystem.

If `name` is NULL, SDL currently uses `(CS_BYTEALIGNCLIENT | CS_OWNDC)`
for the style, regardless of what is specified here.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMain](CategoryMain.html)
