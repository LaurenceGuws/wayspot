# SDL_SetPointerProperty

Set a pointer property in a group of properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetPointerProperty(SDL_PropertiesID props, const char *name, void *value);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to modify. |
| const char \* | **name** | the name of the property to modify. |
| void \* | **value** | the new value of the property, or NULL to delete the property. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetPointerProperty](SDL_GetPointerProperty.html)
- [SDL_HasProperty](SDL_HasProperty.html)
- [SDL_SetBooleanProperty](SDL_SetBooleanProperty.html)
- [SDL_SetFloatProperty](SDL_SetFloatProperty.html)
- [SDL_SetNumberProperty](SDL_SetNumberProperty.html)
- [SDL_SetPointerPropertyWithCleanup](SDL_SetPointerPropertyWithCleanup.html)
- [SDL_SetStringProperty](SDL_SetStringProperty.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
