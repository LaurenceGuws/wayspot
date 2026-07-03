# SDL_StorageReady

Checks if the storage container is ready to use.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_StorageReady(SDL_Storage *storage);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Storage](SDL_Storage.html) \* | **storage** | a storage container to query. |

## Return Value

(bool) Returns true if the container is ready, false otherwise.

## Remarks

This function should be called in regular intervals until it returns
true - however, it is not recommended to spinwait on this call, as the
backend may depend on a synchronous message loop. You might instead poll
this in your game's main loop while processing events and drawing a
loading screen.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
