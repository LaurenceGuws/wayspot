# CategoryAsyncIO

SDL offers a way to perform I/O asynchronously. This allows an app to
read or write files without waiting for data to actually transfer; the
functions that request I/O never block while the request is fulfilled.

Instead, the data moves in the background and the app can check for
results at their leisure.

This is more complicated than just reading and writing files in a
synchronous way, but it can allow for more efficiency, and never having
framerate drops as the hard drive catches up, etc.

The general usage pattern for async I/O is:

- Create one or more [SDL_AsyncIOQueue](SDL_AsyncIOQueue.html) objects.
- Open files with [SDL_AsyncIOFromFile](SDL_AsyncIOFromFile.html).
- Start I/O tasks to the files with
  [SDL_ReadAsyncIO](SDL_ReadAsyncIO.html) or
  [SDL_WriteAsyncIO](SDL_WriteAsyncIO.html), putting those tasks into
  one of the queues.
- Later on, use [SDL_GetAsyncIOResult](SDL_GetAsyncIOResult.html) on a
  queue to see if any task is finished without blocking. Tasks might
  finish in any order with success or failure.
- When all your tasks are done, close the file with
  [SDL_CloseAsyncIO](SDL_CloseAsyncIO.html). This also generates a task,
  since it might flush data to disk!

This all works, without blocking, in a single thread, but one can also
wait on a queue in a background thread, sleeping until new results have
arrived:

- Call [SDL_WaitAsyncIOResult](SDL_WaitAsyncIOResult.html) from one or
  more threads to efficiently block until new tasks complete.
- When shutting down, call
  [SDL_SignalAsyncIOQueue](SDL_SignalAsyncIOQueue.html) to unblock any
  sleeping threads despite there being no new tasks completed.

And, of course, to match the synchronous
[SDL_LoadFile](SDL_LoadFile.html), we offer
[SDL_LoadFileAsync](SDL_LoadFileAsync.html) as a convenience function.
This will handle allocating a buffer, slurping in the file data, and
null-terminating it; you still check for results later.

Behind the scenes, SDL will use newer, efficient APIs on platforms that
support them: Linux's io_uring and Windows 11's IoRing, for example. If
those technologies aren't available, SDL will offload the work to a
thread pool that will manage otherwise-synchronous loads without
blocking the app.

## Best Practices

Simple non-blocking I/O--for an app that just wants to pick up data
whenever it's ready without losing framerate waiting on disks to
spin--can use whatever pattern works well for the program. In this case,
simply call [SDL_ReadAsyncIO](SDL_ReadAsyncIO.html), or maybe
[SDL_LoadFileAsync](SDL_LoadFileAsync.html), as needed. Once a frame,
call [SDL_GetAsyncIOResult](SDL_GetAsyncIOResult.html) to check for any
completed tasks and deal with the data as it arrives.

If two separate pieces of the same program need their own I/O, it is
legal for each to create their own queue. This will prevent either piece
from accidentally consuming the other's completed tasks. Each queue does
require some amount of resources, but it is not an overwhelming cost. Do
not make a queue for each task, however. It is better to put many tasks
into a single queue. They will be reported in order of completion, not
in the order they were submitted, so it doesn't generally matter what
order tasks are started.

One async I/O queue can be shared by multiple threads, or one thread can
have more than one queue, but the most efficient way--if ruthless
efficiency is the goal--is to have one queue per thread, with multiple
threads working in parallel, and attempt to keep each queue loaded with
tasks that are both started by and consumed by the same thread. On
modern platforms that can use newer interfaces, this can keep data
flowing as efficiently as possible all the way from storage hardware to
the app, with no contention between threads for access to the same
queue.

Written data is not guaranteed to make it to physical media by the time
a closing task is completed, unless
[SDL_CloseAsyncIO](SDL_CloseAsyncIO.html) is called with its `flush`
parameter set to true, which is to say that a successful result here can
still result in lost data during an unfortunately-timed power outage if
not flushed. However, flushing will take longer and may be unnecessary,
depending on the app's needs.

## Functions

- [SDL_AsyncIOFromFile](SDL_AsyncIOFromFile.html)
- [SDL_CloseAsyncIO](SDL_CloseAsyncIO.html)
- [SDL_CreateAsyncIOQueue](SDL_CreateAsyncIOQueue.html)
- [SDL_DestroyAsyncIOQueue](SDL_DestroyAsyncIOQueue.html)
- [SDL_GetAsyncIOResult](SDL_GetAsyncIOResult.html)
- [SDL_GetAsyncIOSize](SDL_GetAsyncIOSize.html)
- [SDL_LoadFileAsync](SDL_LoadFileAsync.html)
- [SDL_ReadAsyncIO](SDL_ReadAsyncIO.html)
- [SDL_SignalAsyncIOQueue](SDL_SignalAsyncIOQueue.html)
- [SDL_WaitAsyncIOResult](SDL_WaitAsyncIOResult.html)
- [SDL_WriteAsyncIO](SDL_WriteAsyncIO.html)

## Datatypes

- [SDL_AsyncIO](SDL_AsyncIO.html)
- [SDL_AsyncIOQueue](SDL_AsyncIOQueue.html)

## Structs

- [SDL_AsyncIOOutcome](SDL_AsyncIOOutcome.html)

## Enums

- [SDL_AsyncIOResult](SDL_AsyncIOResult.html)
- [SDL_AsyncIOTaskType](SDL_AsyncIOTaskType.html)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
