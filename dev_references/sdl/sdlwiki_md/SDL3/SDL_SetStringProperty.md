# SDL_SetStringProperty

Set a string property in a group of properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetStringProperty(SDL_PropertiesID props, const char *name, const char *value);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to modify. |
| const char \* | **name** | the name of the property to modify. |
| const char \* | **value** | the new value of the property, or NULL to delete the property. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function makes a copy of the string; the caller does not have to
preserve the data after this call completes.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetStringProperty](SDL_GetStringProperty.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
