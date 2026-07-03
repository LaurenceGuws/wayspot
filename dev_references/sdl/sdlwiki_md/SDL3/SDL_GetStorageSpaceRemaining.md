# SDL_GetStorageSpaceRemaining

Queries the remaining space in a storage container.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint64 SDL_GetStorageSpaceRemaining(SDL_Storage *storage);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Storage](SDL_Storage.html) \* | **storage** | a storage container to query. |

## Return Value

([Uint64](Uint64.html)) Returns the amount of remaining space, in bytes.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_StorageReady](SDL_StorageReady.html)
- [SDL_WriteStorageFile](SDL_WriteStorageFile.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
