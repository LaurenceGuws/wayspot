# SDL_HINT_STORAGE_USER_DRIVER

A variable that specifies a backend to use for user storage.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_STORAGE_USER_DRIVER "SDL_STORAGE_USER_DRIVER"
```

</div>

## Remarks

By default, SDL will try all available storage backends in a reasonable
order until it finds one that can work, but this hint allows the app or
user to force a specific target, such as "pc" if, say, you are on Steam
but want to avoid SteamRemoteStorage for user data.

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
