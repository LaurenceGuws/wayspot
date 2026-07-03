# SDL_CopyProperties

Copy a group of properties.

## Header File

Defined in
[\<SDL3/SDL_properties.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_properties.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_CopyProperties(SDL_PropertiesID src, SDL_PropertiesID dst);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **src** | the properties to copy. |
| [SDL_PropertiesID](SDL_PropertiesID.html) | **dst** | the destination properties. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Copy all the properties from one group of properties to another, with
the exception of properties requiring cleanup (set using
[SDL_SetPointerPropertyWithCleanup](SDL_SetPointerPropertyWithCleanup.html)()),
which will not be copied. Any property that already exists on `dst` will
be overwritten.

## Thread Safety

It is safe to call this function from any thread. This function acquires
simultaneous mutex locks on both the source and destination property
sets.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryProperties](CategoryProperties.html)
