# SDL_ReadStorageFile

Synchronously read a file from a storage container into a
client-provided buffer.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_ReadStorageFile(SDL_Storage *storage, const char *path, void *destination, Uint64 length);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Storage](SDL_Storage.html) \* | **storage** | a storage container to read from. |
| const char \* | **path** | the relative path of the file to read. |
| void \* | **destination** | a client-provided buffer to read the file into. |
| [Uint64](Uint64.html) | **length** | the length of the destination buffer. |

## Return Value

(bool) Returns true if the file was read or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The value of `length` must match the length of the file exactly; call
[SDL_GetStorageFileSize](SDL_GetStorageFileSize.html)() to get this
value. This behavior may be relaxed in a future release.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetStorageFileSize](SDL_GetStorageFileSize.html)
- [SDL_StorageReady](SDL_StorageReady.html)
- [SDL_WriteStorageFile](SDL_WriteStorageFile.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
