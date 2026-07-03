# SDL_PLATFORM_WIN32

A preprocessor macro that is only defined if compiling for desktop
Windows.

## Header File

Defined in
[\<SDL3/SDL_platform_defines.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_platform_defines.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PLATFORM_WIN32 1
```

</div>

## Remarks

Despite the "32", this also covers 64-bit Windows; as an informal
convention, its system layer tends to still be referred to as "the Win32
API."

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPlatform](CategoryPlatform.html)
