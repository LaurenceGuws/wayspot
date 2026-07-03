# SDL_LIL_ENDIAN

A value to represent littleendian byteorder.

## Header File

Defined in
[\<SDL3/SDL_endian.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_endian.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_LIL_ENDIAN  1234
```

</div>

## Remarks

This is used with the preprocessor macro
[SDL_BYTEORDER](SDL_BYTEORDER.html), to determine a platform's byte
ordering:

<div id="cb2" class="sourceCode">

``` sourceCode
#if SDL_BYTEORDER == SDL_LIL_ENDIAN
SDL_Log("This system is littleendian.");
#endif
```

</div>

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_BYTEORDER](SDL_BYTEORDER.html)
- [SDL_BIG_ENDIAN](SDL_BIG_ENDIAN.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryEndian](CategoryEndian.html)
