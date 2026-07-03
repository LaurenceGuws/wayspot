# SDL_EnumerateDirectoryCallback

Callback for directory enumeration.

## Header File

Defined in
[\<SDL3/SDL_filesystem.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_filesystem.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef SDL_EnumerationResult (SDLCALL *SDL_EnumerateDirectoryCallback)(void *userdata, const char *dirname, const char *fname);
```

</div>

## Function Parameters

|              |                                                           |
|--------------|-----------------------------------------------------------|
| **userdata** | an app-controlled pointer that is passed to the callback. |
| **dirname**  | the directory that is being enumerated.                   |
| **fname**    | the next entry in the enumeration.                        |

## Return Value

Returns how the enumeration should proceed.

## Remarks

Enumeration of directory entries will continue until either all entries
have been provided to the callback, or the callback has requested a stop
through its return value.

Returning [SDL_ENUM_CONTINUE](SDL_ENUM_CONTINUE.html) will let
enumeration proceed, calling the callback with further entries.
[SDL_ENUM_SUCCESS](SDL_ENUM_SUCCESS.html) and
[SDL_ENUM_FAILURE](SDL_ENUM_FAILURE.html) will terminate the enumeration
early, and dictate the return value of the enumeration function itself.

`dirname` is guaranteed to end with a path separator ('\\ on Windows,
'/' on most other platforms).

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_EnumerateDirectory](SDL_EnumerateDirectory.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryFilesystem](CategoryFilesystem.html)
