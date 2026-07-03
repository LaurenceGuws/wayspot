# SDL_INLINE

A macro to request a function be inlined.

## Header File

Defined in
[\<SDL3/SDL_begin_code.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_begin_code.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_INLINE __inline
```

</div>

## Remarks

This is a hint to the compiler to inline a function. The compiler is
free to ignore this request. On compilers without inline support, this
is defined to nothing.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryBeginCode](CategoryBeginCode.html)
