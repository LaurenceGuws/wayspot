# SDL_DestroyAsyncIOQueue

Destroy a previously-created async I/O task queue.

## Header File

Defined in
[\<SDL3/SDL_asyncio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_asyncio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyAsyncIOQueue(SDL_AsyncIOQueue *queue);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AsyncIOQueue](SDL_AsyncIOQueue.html) \* | **queue** | the task queue to destroy. |

## Remarks

If there are still tasks pending for this queue, this call will block
until those tasks are finished. All those tasks will be deallocated.
Their results will be lost to the app.

Any pending reads from [SDL_LoadFileAsync](SDL_LoadFileAsync.html)()
that are still in this queue will have their buffers deallocated by this
function, to prevent a memory leak.

Once this function is called, the queue is no longer valid and should
not be used, including by other threads that might access it while
destruction is blocking on pending tasks.

Do not destroy a queue that still has threads waiting on it through
[SDL_WaitAsyncIOResult](SDL_WaitAsyncIOResult.html)(). You can call
[SDL_SignalAsyncIOQueue](SDL_SignalAsyncIOQueue.html)() first to unblock
those threads, and take measures (such as
[SDL_WaitThread](SDL_WaitThread.html)()) to make sure they have finished
their wait and won't wait on the queue again.

## Thread Safety

It is safe to call this function from any thread, so long as no other
thread is waiting on the queue with
[SDL_WaitAsyncIOResult](SDL_WaitAsyncIOResult.html).

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAsyncIO](CategoryAsyncIO.html)
