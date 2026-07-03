# SDL_OpenFileStorage

Opens up a container for local filesystem storage.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Storage * SDL_OpenFileStorage(const char *path);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **path** | the base path prepended to all storage paths, or NULL for no base path. |

## Return Value

([SDL_Storage](SDL_Storage.html) \*) Returns a filesystem storage
container on success or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This is provided for development and tools. Portable applications should
use [SDL_OpenTitleStorage](SDL_OpenTitleStorage.html)() for access to
game data and [SDL_OpenUserStorage](SDL_OpenUserStorage.html)() for
access to user data.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseStorage](SDL_CloseStorage.html)
- [SDL_GetStorageFileSize](SDL_GetStorageFileSize.html)
- [SDL_GetStorageSpaceRemaining](SDL_GetStorageSpaceRemaining.html)
- [SDL_OpenTitleStorage](SDL_OpenTitleStorage.html)
- [SDL_OpenUserStorage](SDL_OpenUserStorage.html)
- [SDL_ReadStorageFile](SDL_ReadStorageFile.html)
- [SDL_WriteStorageFile](SDL_WriteStorageFile.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
