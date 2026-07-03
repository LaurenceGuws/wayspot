# SDL_SetMainReady

Circumvent failure of [SDL_Init](SDL_Init.html)() when not using
[SDL_main](SDL_main.html)() as an entry point.

## Header File

Defined in
[\<SDL3/SDL_main.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_main.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetMainReady(void);
```

</div>

## Remarks

This function is defined in [SDL_main](SDL_main.html).h, along with the
preprocessor rule to redefine main() as [SDL_main](SDL_main.html)().
Thus to ensure that your main() function will not be changed it is
necessary to define [SDL_MAIN_HANDLED](SDL_MAIN_HANDLED.html) before
including SDL.h.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_Init](SDL_Init.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMain](CategoryMain.html)
