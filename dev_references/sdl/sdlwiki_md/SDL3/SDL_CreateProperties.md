# SDL_CreateProperties

Create a group of properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PropertiesID SDL_CreateProperties(void);
```

</div>

## Return Value

([SDL_PropertiesID](SDL_PropertiesID.html)) Returns an ID for a new
group of properties, or 0 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

All properties are automatically destroyed when
[SDL_Quit](SDL_Quit.html)() is called.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DestroyProperties](SDL_DestroyProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
