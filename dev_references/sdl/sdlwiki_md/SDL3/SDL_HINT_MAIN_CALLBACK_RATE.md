# SDL_HINT_MAIN_CALLBACK_RATE

Request [SDL_AppIterate](SDL_AppIterate.html)() be called at a specific
rate.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_MAIN_CALLBACK_RATE "SDL_MAIN_CALLBACK_RATE"
```

</div>

## Remarks

If this is set to a number, it represents Hz, so "60" means try to
iterate 60 times per second. "0" means to iterate as fast as possible.
Negative values are illegal, but reserved, in case they are useful in a
future revision of SDL.

There are other strings that have special meaning. If set to
"waitevent", [SDL_AppIterate](SDL_AppIterate.html) will not be called
until new event(s) have arrived (and been processed by
[SDL_AppEvent](SDL_AppEvent.html)). This can be useful for apps that are
completely idle except in response to input.

On some platforms, or if you are using [SDL_main](SDL_main.html) instead
of [SDL_AppIterate](SDL_AppIterate.html), this hint is ignored. When the
hint can be used, it is allowed to be changed at any time.

This defaults to 0, and specifying NULL for the hint's value will
restore the default.

This doesn't have to be an integer value. For example, "59.94" won't be
rounded to an integer rate; the digits after the decimal are actually
respected.

This hint can be set anytime.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
