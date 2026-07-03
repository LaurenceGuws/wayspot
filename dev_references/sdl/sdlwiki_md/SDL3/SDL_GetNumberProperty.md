# SDL_GetNumberProperty

Get a number property from a group of properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Sint64 SDL_GetNumberProperty(SDL_PropertiesID props, const char *name, Sint64 default_value);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to query. |
| const char \* | **name** | the name of the property to query. |
| [Sint64](Sint64.html) | **default_value** | the default value of the property. |

## Return Value

([Sint64](Sint64.html)) Returns the value of the property, or
`default_value` if it is not set or not a number property.

## Remarks

You can use [SDL_GetPropertyType](SDL_GetPropertyType.html)() to query
whether the property exists and is a number property.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetPropertyType](SDL_GetPropertyType.html)
- [SDL_HasProperty](SDL_HasProperty.html)
- [SDL_SetNumberProperty](SDL_SetNumberProperty.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
