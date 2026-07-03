# SDL_GetPointerProperty

Get a pointer property from a group of properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void * SDL_GetPointerProperty(SDL_PropertiesID props, const char *name, void *default_value);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to query. |
| const char \* | **name** | the name of the property to query. |
| void \* | **default_value** | the default value of the property. |

## Return Value

(void \*) Returns the value of the property, or `default_value` if it is
not set or not a pointer property.

## Remarks

By convention, the names of properties that SDL exposes on objects will
start with "SDL.", and properties that SDL uses internally will start
with "SDL.internal.". These should be considered read-only and should
not be modified by applications.

## Thread Safety

It is safe to call this function from any thread, although the data
returned is not protected and could potentially be freed if you call
[SDL_SetPointerProperty](SDL_SetPointerProperty.html)() or
[SDL_ClearProperty](SDL_ClearProperty.html)() on these properties from
another thread. If you need to avoid this, use
[SDL_LockProperties](SDL_LockProperties.html)() and
[SDL_UnlockProperties](SDL_UnlockProperties.html)().

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetBooleanProperty](SDL_GetBooleanProperty.html)
- [SDL_GetFloatProperty](SDL_GetFloatProperty.html)
- [SDL_GetNumberProperty](SDL_GetNumberProperty.html)
- [SDL_GetPropertyType](SDL_GetPropertyType.html)
- [SDL_GetStringProperty](SDL_GetStringProperty.html)
- [SDL_HasProperty](SDL_HasProperty.html)
- [SDL_SetPointerProperty](SDL_SetPointerProperty.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
