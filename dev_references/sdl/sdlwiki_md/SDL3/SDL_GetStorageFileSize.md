# SDL_GetStorageFileSize

Query the size of a file within a storage container.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetStorageFileSize(SDL_Storage *storage, const char *path, Uint64 *length);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Storage](SDL_Storage.html) \* | **storage** | a storage container to query. |
| const char \* | **path** | the relative path of the file to query. |
| [Uint64](Uint64.html) \* | **length** | a pointer to be filled with the file's length. |

## Return Value

(bool) Returns true if the file could be queried or false on failure;
call [SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_ReadStorageFile](SDL_ReadStorageFile.html)
- [SDL_StorageReady](SDL_StorageReady.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
