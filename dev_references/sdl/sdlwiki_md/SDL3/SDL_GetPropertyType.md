# SDL_GetPropertyType

Get the type of a property in a group of properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PropertyType SDL_GetPropertyType(SDL_PropertiesID props, const char *name);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to query. |
| const char \* | **name** | the name of the property to query. |

## Return Value

([SDL_PropertyType](SDL_PropertyType.html)) Returns the type of the
property, or [SDL_PROPERTY_TYPE_INVALID](SDL_PROPERTY_TYPE_INVALID.html)
if it is not set.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_HasProperty](SDL_HasProperty.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
