# SDL_EnumeratePropertiesCallback

A callback used to enumerate all the properties in a group of
properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void (SDLCALL *SDL_EnumeratePropertiesCallback)(void *userdata, SDL_PropertiesID props, const char *name);
```

</div>

## Function Parameters

|  |  |
|----|----|
| **userdata** | an app-defined pointer passed to the callback. |
| **props** | the [SDL_PropertiesID](SDL_PropertiesID.html) that is being enumerated. |
| **name** | the next property name in the enumeration. |

## Remarks

This callback is called from
[SDL_EnumerateProperties](SDL_EnumerateProperties.html)(), and is called
once per property in the set.

## Thread Safety

[SDL_EnumerateProperties](SDL_EnumerateProperties.html) holds a lock on
`props` during this callback.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_EnumerateProperties](SDL_EnumerateProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryProperties](CategoryProperties.html)
