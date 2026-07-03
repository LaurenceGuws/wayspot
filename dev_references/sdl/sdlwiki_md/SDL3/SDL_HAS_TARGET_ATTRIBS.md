# SDL_HAS_TARGET_ATTRIBS

A macro to decide if the compiler supports `__attribute__((target))`.

## Header File

Defined in
[\<SDL3/SDL_intrin.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_intrin.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HAS_TARGET_ATTRIBS
```

</div>

## Remarks

Even though this is defined in SDL's public headers, it is generally not
used directly by apps. Apps should probably just use
[SDL_TARGETING](SDL_TARGETING.html) directly, instead.

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_TARGETING](SDL_TARGETING.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryIntrinsics](CategoryIntrinsics.html)
