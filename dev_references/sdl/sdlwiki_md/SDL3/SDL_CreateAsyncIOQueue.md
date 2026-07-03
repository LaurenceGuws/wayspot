# SDL_CreateAsyncIOQueue

Create a task queue for tracking multiple I/O operations.

## Header File

Defined in
[\<SDL3/SDL_asyncio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_asyncio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_AsyncIOQueue * SDL_CreateAsyncIOQueue(void);
```

</div>

## Return Value

([SDL_AsyncIOQueue](SDL_AsyncIOQueue.html) \*) Returns a new task queue
object or NULL if there was an error; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Async I/O operations are assigned to a queue when started. The queue can
be checked for completed tasks thereafter.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DestroyAsyncIOQueue](SDL_DestroyAsyncIOQueue.html)
- [SDL_GetAsyncIOResult](SDL_GetAsyncIOResult.html)
- [SDL_WaitAsyncIOResult](SDL_WaitAsyncIOResult.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAsyncIO](CategoryAsyncIO.html)
