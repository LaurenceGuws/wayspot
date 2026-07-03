# SDL_RESTRICT

A macro to tag a pointer variable, to help with pointer aliasing.

## Header File

Defined in
[\<SDL3/SDL_begin_code.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_begin_code.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_RESTRICT __restrict
```

</div>

## Remarks

A good explanation of the restrict keyword is here:

<https://en.wikipedia.org/wiki/Restrict>

On compilers without restrict support, this is defined to nothing.

## Version

This macro is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryBeginCode](CategoryBeginCode.html)
