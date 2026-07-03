# SDL_LockSpinlock

Lock a spin lock by setting it to a non-zero value.

## Header File

Defined in
[\<SDL3/SDL_atomic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_atomic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_LockSpinlock(SDL_SpinLock *lock);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_SpinLock](SDL_SpinLock.html) \* | **lock** | a pointer to a lock variable. |

## Remarks

***Please note that spinlocks are dangerous if you don't know what
you're doing. Please be careful using any sort of spinlock!***

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_TryLockSpinlock](SDL_TryLockSpinlock.html)
- [SDL_UnlockSpinlock](SDL_UnlockSpinlock.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAtomic](CategoryAtomic.html)
