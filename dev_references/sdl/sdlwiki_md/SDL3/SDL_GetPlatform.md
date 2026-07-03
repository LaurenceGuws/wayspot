# SDL_GetPlatform

Get the name of the platform.

## Header File

Defined in
[\<SDL3/SDL_platform.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_platform.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetPlatform(void);
```

</div>

## Return Value

(const char \*) Returns the name of the platform. If the correct
platform name is not available, returns a string beginning with the text
"Unknown".

## Remarks

Here are the names returned for some (but not all) supported platforms:

- "Windows"
- "macOS"
- "Linux"
- "iOS"
- "Android"

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryPlatform](CategoryPlatform.html)
