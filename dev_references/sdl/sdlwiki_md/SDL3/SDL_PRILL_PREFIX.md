# SDL_PRILL_PREFIX

A printf-formatting string prefix for a `long long` value.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PRILL_PREFIX "ll"
```

</div>

## Remarks

This is just the prefix! You probably actually want
[SDL_PRILLd](SDL_PRILLd.html), [SDL_PRILLu](SDL_PRILLu.html),
[SDL_PRILLx](SDL_PRILLx.html), or [SDL_PRILLX](SDL_PRILLX.html) instead.

Use it like this:

<div id="cb2" class="sourceCode">

``` sourceCode
SDL_Log("There are %" SDL_PRILL_PREFIX "d bottles of beer on the wall.", bottles);
```

</div>

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
