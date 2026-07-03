# SDL_PLATFORM_WINDOWS

A preprocessor macro that is only defined if compiling for Windows.

## Header File

Defined in
[\<SDL3/SDL_platform_defines.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_platform_defines.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PLATFORM_WINDOWS 1
```

</div>

## Remarks

This also covers several other platforms, like Microsoft GDK, Xbox,
WinRT, etc. Each will have their own more-specific platform macros, too.

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_PLATFORM_WIN32](SDL_PLATFORM_WIN32.html)
- [SDL_PLATFORM_XBOXONE](SDL_PLATFORM_XBOXONE.html)
- [SDL_PLATFORM_XBOXSERIES](SDL_PLATFORM_XBOXSERIES.html)
- [SDL_PLATFORM_WINGDK](SDL_PLATFORM_WINGDK.html)
- [SDL_PLATFORM_GDK](SDL_PLATFORM_GDK.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPlatform](CategoryPlatform.html)
