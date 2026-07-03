# SDL_CloseStorage

Closes and frees a storage container.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_CloseStorage(SDL_Storage *storage);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Storage](SDL_Storage.html) \* | **storage** | a storage container to close. |

## Return Value

(bool) Returns true if the container was freed with no errors, false
otherwise; call [SDL_GetError](SDL_GetError.html)() for more
information. Even if the function returns an error, the container data
will be freed; the error is only for informational purposes.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_OpenFileStorage](SDL_OpenFileStorage.html)
- [SDL_OpenStorage](SDL_OpenStorage.html)
- [SDL_OpenTitleStorage](SDL_OpenTitleStorage.html)
- [SDL_OpenUserStorage](SDL_OpenUserStorage.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
