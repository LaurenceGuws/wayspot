# SDL_VERSIONNUM

This macro turns the version numbers into a numeric value.

## Header File

Defined in
[\<SDL3/SDL_version.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_version.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_VERSIONNUM(major, minor, patch) \
    ((major) * 1000000 + (minor) * 1000 + (patch))
```

</div>

## Macro Parameters

|           |                           |
|-----------|---------------------------|
| **major** | the major version number. |
| **minor** | the minorversion number.  |
| **patch** | the patch version number. |

## Remarks

(1,2,3) becomes 1002003.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryVersion](CategoryVersion.html)
