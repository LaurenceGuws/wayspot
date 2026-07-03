# SDL_GetGlobalProperties

Get the global SDL properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PropertiesID SDL_GetGlobalProperties(void);
```

</div>

## Return Value

([SDL_PropertiesID](SDL_PropertiesID.html)) Returns a valid property ID
on success or 0 on failure; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
