# SDL_GetGDKTaskQueue

Gets a reference to the global async task queue handle for GDK,
initializing if needed.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetGDKTaskQueue(XTaskQueueHandle *outTaskQueue);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| XTaskQueueHandle \* | **outTaskQueue** | a pointer to be filled in with task queue handle. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Once you are done with the task queue, you should call
XTaskQueueCloseHandle to reduce the reference count to avoid a resource
leak.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
