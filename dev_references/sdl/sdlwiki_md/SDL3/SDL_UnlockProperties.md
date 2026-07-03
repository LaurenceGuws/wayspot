# SDL_UnlockProperties

Unlock a group of properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_UnlockProperties(SDL_PropertiesID props);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to unlock. |

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_LockProperties](SDL_LockProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
