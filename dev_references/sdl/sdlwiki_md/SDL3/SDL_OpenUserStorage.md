# SDL_OpenUserStorage

Opens up a container for a user's unique read/write filesystem.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Storage * SDL_OpenUserStorage(const char *org, const char *app, SDL_PropertiesID props);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **org** | the name of your organization. |
| const char \* | **app** | the name of your application. |
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | a property list that may contain backend-specific information. |

## Return Value

([SDL_Storage](SDL_Storage.html) \*) Returns a user storage container on
success or NULL on failure; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Remarks

While title storage can generally be kept open throughout runtime, user
storage should only be opened when the client is ready to read/write
files. This allows the backend to properly batch file operations and
flush them when the container has been closed; ensuring safe and optimal
save I/O.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseStorage](SDL_CloseStorage.html)
- [SDL_GetStorageFileSize](SDL_GetStorageFileSize.html)
- [SDL_GetStorageSpaceRemaining](SDL_GetStorageSpaceRemaining.html)
- [SDL_OpenTitleStorage](SDL_OpenTitleStorage.html)
- [SDL_ReadStorageFile](SDL_ReadStorageFile.html)
- [SDL_StorageReady](SDL_StorageReady.html)
- [SDL_WriteStorageFile](SDL_WriteStorageFile.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
