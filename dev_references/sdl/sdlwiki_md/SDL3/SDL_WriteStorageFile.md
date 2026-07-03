# SDL_WriteStorageFile

Synchronously write a file from client memory into a storage container.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_WriteStorageFile(SDL_Storage *storage, const char *path, const void *source, Uint64 length);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Storage](SDL_Storage.html) \* | **storage** | a storage container to write to. |
| const char \* | **path** | the relative path of the file to write. |
| const void \* | **source** | a client-provided buffer to write from. |
| [Uint64](Uint64.html) | **length** | the length of the source buffer. |

## Return Value

(bool) Returns true if the file was written or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetStorageSpaceRemaining](SDL_GetStorageSpaceRemaining.html)
- [SDL_ReadStorageFile](SDL_ReadStorageFile.html)
- [SDL_StorageReady](SDL_StorageReady.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
