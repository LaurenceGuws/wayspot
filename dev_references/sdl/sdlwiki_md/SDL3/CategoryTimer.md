# CategoryTimer

SDL provides time management functionality. It is useful for dealing
with (usually) small durations of time.

This is not to be confused with *calendar time* management, which is
provided by [CategoryTime](CategoryTime.html).

This category covers measuring time elapsed
([SDL_GetTicks](SDL_GetTicks.html)(),
[SDL_GetPerformanceCounter](SDL_GetPerformanceCounter.html)()), putting
a thread to sleep for a certain amount of time
([SDL_Delay](SDL_Delay.html)(), [SDL_DelayNS](SDL_DelayNS.html)(),
[SDL_DelayPrecise](SDL_DelayPrecise.html)()), and firing a callback
function after a certain amount of time has elapsed
([SDL_AddTimer](SDL_AddTimer.html)(), etc).

There are also useful macros to convert between time units, like
[SDL_SECONDS_TO_NS](SDL_SECONDS_TO_NS.html)() and such.

## Functions

- [SDL_AddTimer](SDL_AddTimer.html)
- [SDL_AddTimerNS](SDL_AddTimerNS.html)
- [SDL_Delay](SDL_Delay.html)
- [SDL_DelayNS](SDL_DelayNS.html)
- [SDL_DelayPrecise](SDL_DelayPrecise.html)
- [SDL_GetPerformanceCounter](SDL_GetPerformanceCounter.html)
- [SDL_GetPerformanceFrequency](SDL_GetPerformanceFrequency.html)
- [SDL_GetTicks](SDL_GetTicks.html)
- [SDL_GetTicksNS](SDL_GetTicksNS.html)
- [SDL_RemoveTimer](SDL_RemoveTimer.html)

## Datatypes

- [SDL_NSTimerCallback](SDL_NSTimerCallback.html)
- [SDL_TimerCallback](SDL_TimerCallback.html)
- [SDL_TimerID](SDL_TimerID.html)

## Structs

- (none.)

## Enums

- (none.)

## Macros

- [SDL_MS_PER_SECOND](SDL_MS_PER_SECOND.html)
- [SDL_MS_TO_NS](SDL_MS_TO_NS.html)
- [SDL_NS_PER_MS](SDL_NS_PER_MS.html)
- [SDL_NS_PER_SECOND](SDL_NS_PER_SECOND.html)
- [SDL_NS_PER_US](SDL_NS_PER_US.html)
- [SDL_NS_TO_MS](SDL_NS_TO_MS.html)
- [SDL_NS_TO_SECONDS](SDL_NS_TO_SECONDS.html)
- [SDL_NS_TO_US](SDL_NS_TO_US.html)
- [SDL_SECONDS_TO_NS](SDL_SECONDS_TO_NS.html)
- [SDL_US_PER_SECOND](SDL_US_PER_SECOND.html)
- [SDL_US_TO_NS](SDL_US_TO_NS.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
