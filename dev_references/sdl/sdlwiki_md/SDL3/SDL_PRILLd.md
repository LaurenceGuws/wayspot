# SDL_PRILLd

A printf-formatting string for a `long long` value.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PRILLd SDL_PRILL_PREFIX "d"
```

</div>

## Remarks

Use it like this:

<div id="cb2" class="sourceCode">

``` sourceCode
SDL_Log("There are %" SDL_PRILLd " bottles of beer on the wall.", bottles);
```

</div>

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
