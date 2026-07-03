# SDL_PLATFORM_LINUX

A preprocessor macro that is only defined if compiling for Linux.

## Header File

Defined in
[\<SDL3/SDL_platform_defines.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_platform_defines.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PLATFORM_LINUX 1
```

</div>

## Remarks

Note that Android, although ostensibly a Linux-based system, will not
define this. It defines
[SDL_PLATFORM_ANDROID](SDL_PLATFORM_ANDROID.html) instead.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPlatform](CategoryPlatform.html)
