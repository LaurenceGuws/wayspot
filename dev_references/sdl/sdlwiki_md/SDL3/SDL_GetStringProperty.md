# SDL_GetStringProperty

Get a string property from a group of properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetStringProperty(SDL_PropertiesID props, const char *name, const char *default_value);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to query. |
| const char \* | **name** | the name of the property to query. |
| const char \* | **default_value** | the default value of the property. |

## Return Value

(const char \*) Returns the value of the property, or `default_value` if
it is not set or not a string property.

## Thread Safety

It is safe to call this function from any thread, although the data
returned is not protected and could potentially be freed if you call
[SDL_SetStringProperty](SDL_SetStringProperty.html)() or
[SDL_ClearProperty](SDL_ClearProperty.html)() on these properties from
another thread. If you need to avoid this, use
[SDL_LockProperties](SDL_LockProperties.html)() and
[SDL_UnlockProperties](SDL_UnlockProperties.html)().

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetPropertyType](SDL_GetPropertyType.html)
- [SDL_HasProperty](SDL_HasProperty.html)
- [SDL_SetStringProperty](SDL_SetStringProperty.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
