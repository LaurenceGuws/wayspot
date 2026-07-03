# SDL_HINT_CAMERA_DRIVER

A variable that decides what camera backend to use.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_CAMERA_DRIVER "SDL_CAMERA_DRIVER"
```

</div>

## Remarks

By default, SDL will try all available camera backends in a reasonable
order until it finds one that can work, but this hint allows the app or
user to force a specific target, such as "directshow" if, say, you are
on Windows Media Foundations but want to try DirectShow instead.

The default value is unset, in which case SDL will try to figure out the
best camera backend on your behalf. This hint needs to be set before
[SDL_Init](SDL_Init.html)() is called to be useful.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
