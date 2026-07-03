# SDL_PRIu32

A printf-formatting string for a [Uint32](Uint32.html) value.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PRIu32 "u"
```

</div>

## Remarks

Use it like this:

<div id="cb2" class="sourceCode">

``` sourceCode
SDL_Log("There are %" SDL_PRIu32 " bottles of beer on the wall.", bottles);
```

</div>

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
