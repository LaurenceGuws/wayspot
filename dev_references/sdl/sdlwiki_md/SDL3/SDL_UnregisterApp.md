# SDL_UnregisterApp

Deregister the win32 window class from an
[SDL_RegisterApp](SDL_RegisterApp.html) call.

## Header File

Defined in
[\<SDL3/SDL_main.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_main.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_UnregisterApp(void);
```

</div>

## Remarks

This can be called to undo the effects of
[SDL_RegisterApp](SDL_RegisterApp.html).

Most applications do not need to, and should not, call this directly;
SDL will call it when deinitializing the video subsystem.

It is safe to call this multiple times, as long as every call is
eventually paired with a prior call to
[SDL_RegisterApp](SDL_RegisterApp.html). The window class will only be
deregistered when the registration counter in
[SDL_RegisterApp](SDL_RegisterApp.html) decrements to zero through calls
to this function.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMain](CategoryMain.html)
