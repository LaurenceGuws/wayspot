# SDL_BIG_ENDIAN

A value to represent bigendian byteorder.

## Header File

Defined in
[\<SDL3/SDL_endian.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_endian.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_BIG_ENDIAN  4321
```

</div>

## Remarks

This is used with the preprocessor macro
[SDL_BYTEORDER](SDL_BYTEORDER.html), to determine a platform's byte
ordering:

<div id="cb2" class="sourceCode">

``` sourceCode
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
SDL_Log("This system is bigendian.");
#endif
```

</div>

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_BYTEORDER](SDL_BYTEORDER.html)
- [SDL_LIL_ENDIAN](SDL_LIL_ENDIAN.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryEndian](CategoryEndian.html)
