# SDL_GUIDToString

Get an ASCII string representation for a given
[SDL_GUID](SDL_GUID.html).

## Header File

Defined in
[\<SDL3/SDL_guid.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_guid.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_GUIDToString(SDL_GUID guid, char *pszGUID, int cbGUID);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GUID](SDL_GUID.html) | **guid** | the [SDL_GUID](SDL_GUID.html) you wish to convert to string. |
| char \* | **pszGUID** | buffer in which to write the ASCII string. |
| int | **cbGUID** | the size of pszGUID, should be at least 33 bytes. |

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_StringToGUID](SDL_StringToGUID.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGUID](CategoryGUID.html)
