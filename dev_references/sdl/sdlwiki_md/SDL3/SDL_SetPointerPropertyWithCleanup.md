# SDL_SetPointerPropertyWithCleanup

Set a pointer property in a group of properties with a cleanup function
that is called when the property is deleted.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetPointerPropertyWithCleanup(SDL_PropertiesID props, const char *name, void *value, SDL_CleanupPropertyCallback cleanup, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to modify. |
| const char \* | **name** | the name of the property to modify. |
| void \* | **value** | the new value of the property, or NULL to delete the property. |
| [SDL_CleanupPropertyCallback](SDL_CleanupPropertyCallback.html) | **cleanup** | the function to call when this property is deleted, or NULL if no cleanup is necessary. |
| void \* | **userdata** | a pointer that is passed to the cleanup function. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The cleanup function is also called if setting the property fails for
any reason.

For simply setting basic data types, like numbers, bools, or strings,
use [SDL_SetNumberProperty](SDL_SetNumberProperty.html),
[SDL_SetBooleanProperty](SDL_SetBooleanProperty.html), or
[SDL_SetStringProperty](SDL_SetStringProperty.html) instead, as those
functions will handle cleanup on your behalf. This function is only for
more complex, custom data.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetPointerProperty](SDL_GetPointerProperty.html)
- [SDL_SetPointerProperty](SDL_SetPointerProperty.html)
- [SDL_CleanupPropertyCallback](SDL_CleanupPropertyCallback.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
