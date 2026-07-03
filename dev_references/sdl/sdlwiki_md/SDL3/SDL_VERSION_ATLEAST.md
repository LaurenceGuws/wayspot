# SDL_VERSION_ATLEAST

This macro will evaluate to true if compiled with SDL at least X.Y.Z.

## Header File

Defined in
[\<SDL3/SDL_version.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_version.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_VERSION_ATLEAST(X, Y, Z) \
    (SDL_VERSION >= SDL_VERSIONNUM(X, Y, Z))
```

</div>

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryVersion](CategoryVersion.html)
