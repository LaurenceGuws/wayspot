# SDL_GetStoragePathInfo

Get information about a filesystem path in a storage container.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetStoragePathInfo(SDL_Storage *storage, const char *path, SDL_PathInfo *info);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Storage](SDL_Storage.html) \* | **storage** | a storage container. |
| const char \* | **path** | the path to query. |
| [SDL_PathInfo](SDL_PathInfo.html) \* | **info** | a pointer filled in with information about the path, or NULL to check for the existence of a file. |

## Return Value

(bool) Returns true on success or false if the file doesn't exist, or
another failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_StorageReady](SDL_StorageReady.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
