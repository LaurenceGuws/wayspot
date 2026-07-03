# SDL_Sandbox

Application sandbox environment.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_Sandbox
{
    SDL_SANDBOX_NONE = 0,
    SDL_SANDBOX_UNKNOWN_CONTAINER,
    SDL_SANDBOX_FLATPAK,
    SDL_SANDBOX_SNAP,
    SDL_SANDBOX_MACOS
} SDL_Sandbox;
```

</div>

## Version

This enum is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html),
[CategorySystem](CategorySystem.html)
