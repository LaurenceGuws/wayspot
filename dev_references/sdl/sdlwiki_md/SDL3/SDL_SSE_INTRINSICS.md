# SDL_SSE_INTRINSICS

Defined if (and only if) the compiler supports Intel SSE intrinsics.

## Header File

Defined in
[\<SDL3/SDL_intrin.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_intrin.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_SSE_INTRINSICS 1
```

</div>

## Remarks

If this macro is defined, SDL will have already included `<xmmintrin.h>`

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_SSE2_INTRINSICS](SDL_SSE2_INTRINSICS.html)
- [SDL_SSE3_INTRINSICS](SDL_SSE3_INTRINSICS.html)
- [SDL_SSE4_1_INTRINSICS](SDL_SSE4_1_INTRINSICS.html)
- [SDL_SSE4_2_INTRINSICS](SDL_SSE4_2_INTRINSICS.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryIntrinsics](CategoryIntrinsics.html)
