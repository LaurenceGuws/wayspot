# SDL_CreateStorageDirectory

Create a directory in a writable storage container.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_CreateStorageDirectory(SDL_Storage *storage, const char *path);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Storage](SDL_Storage.html) \* | **storage** | a storage container. |
| const char \* | **path** | the path of the directory to create. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_StorageReady](SDL_StorageReady.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
