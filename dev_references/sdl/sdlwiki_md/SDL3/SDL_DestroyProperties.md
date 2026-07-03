# SDL_DestroyProperties

Destroy a group of properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyProperties(SDL_PropertiesID props);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to destroy. |

## Remarks

All properties are deleted and their cleanup functions will be called,
if any.

## Thread Safety

This function should not be called while these properties are locked or
other threads might be setting or getting values from these properties.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateProperties](SDL_CreateProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
