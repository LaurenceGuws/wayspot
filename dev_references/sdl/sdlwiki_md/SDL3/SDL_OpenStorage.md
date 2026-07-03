# SDL_OpenStorage

Opens up a container using a client-provided storage interface.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Storage * SDL_OpenStorage(const SDL_StorageInterface *iface, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_StorageInterface](SDL_StorageInterface.html) \* | **iface** | the interface that implements this storage, initialized using [SDL_INIT_INTERFACE](SDL_INIT_INTERFACE.html)(). |
| void \* | **userdata** | the pointer that will be passed to the interface functions. |

## Return Value

([SDL_Storage](SDL_Storage.html) \*) Returns a storage container on
success or NULL on failure; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Remarks

Applications do not need to use this function unless they are providing
their own [SDL_Storage](SDL_Storage.html) implementation. If you just
need an [SDL_Storage](SDL_Storage.html), you should use the built-in
implementations in SDL, like
[SDL_OpenTitleStorage](SDL_OpenTitleStorage.html)() or
[SDL_OpenUserStorage](SDL_OpenUserStorage.html)().

This function makes a copy of `iface` and the caller does not need to
keep it around after this call.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseStorage](SDL_CloseStorage.html)
- [SDL_GetStorageFileSize](SDL_GetStorageFileSize.html)
- [SDL_GetStorageSpaceRemaining](SDL_GetStorageSpaceRemaining.html)
- [SDL_INIT_INTERFACE](SDL_INIT_INTERFACE.html)
- [SDL_ReadStorageFile](SDL_ReadStorageFile.html)
- [SDL_StorageReady](SDL_StorageReady.html)
- [SDL_WriteStorageFile](SDL_WriteStorageFile.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
