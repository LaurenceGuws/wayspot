# CategoryMouse

Any GUI application has to deal with the mouse, and SDL provides
functions to manage mouse input and the displayed cursor.

Most interactions with the mouse will come through the event subsystem.
Moving a mouse generates an
[SDL_EVENT_MOUSE_MOTION](SDL_EVENT_MOUSE_MOTION.html) event, pushing a
button generates
[SDL_EVENT_MOUSE_BUTTON_DOWN](SDL_EVENT_MOUSE_BUTTON_DOWN.html), etc,
but one can also query the current state of the mouse at any time with
[SDL_GetMouseState](SDL_GetMouseState.html)().

For certain games, it's useful to disassociate the mouse cursor from
mouse input. An FPS, for example, would not want the player's motion to
stop as the mouse hits the edge of the window. For these scenarios, use
[SDL_SetWindowRelativeMouseMode](SDL_SetWindowRelativeMouseMode.html)(),
which hides the cursor, grabs mouse input to the window, and reads mouse
input no matter how far it moves.

Games that want the system to track the mouse but want to draw their own
cursor can use [SDL_HideCursor](SDL_HideCursor.html)() and
[SDL_ShowCursor](SDL_ShowCursor.html)(). It might be more efficient to
let the system manage the cursor, if possible, using
[SDL_SetCursor](SDL_SetCursor.html)() with a custom image made through
[SDL_CreateColorCursor](SDL_CreateColorCursor.html)(), or perhaps just a
specific system cursor from
[SDL_CreateSystemCursor](SDL_CreateSystemCursor.html)().

SDL can, on many platforms, differentiate between multiple connected
mice, allowing for interesting input scenarios and multiplayer games.
They can be enumerated with [SDL_GetMice](SDL_GetMice.html)(), and SDL
will send [SDL_EVENT_MOUSE_ADDED](SDL_EVENT_MOUSE_ADDED.html) and
[SDL_EVENT_MOUSE_REMOVED](SDL_EVENT_MOUSE_REMOVED.html) events as they
are connected and unplugged.

Since many apps only care about basic mouse input, SDL offers a virtual
mouse device for touch and pen input, which often can make a desktop
application work on a touchscreen phone without any code changes. Apps
that care about touch/pen separately from mouse input should filter out
events with a `which` field of
[SDL_TOUCH_MOUSEID](SDL_TOUCH_MOUSEID.html)/SDL_PEN_MOUSEID.

## Functions

- [SDL_CaptureMouse](SDL_CaptureMouse.html)
- [SDL_CreateAnimatedCursor](SDL_CreateAnimatedCursor.html)
- [SDL_CreateColorCursor](SDL_CreateColorCursor.html)
- [SDL_CreateCursor](SDL_CreateCursor.html)
- [SDL_CreateSystemCursor](SDL_CreateSystemCursor.html)
- [SDL_CursorVisible](SDL_CursorVisible.html)
- [SDL_DestroyCursor](SDL_DestroyCursor.html)
- [SDL_GetCursor](SDL_GetCursor.html)
- [SDL_GetDefaultCursor](SDL_GetDefaultCursor.html)
- [SDL_GetGlobalMouseState](SDL_GetGlobalMouseState.html)
- [SDL_GetMice](SDL_GetMice.html)
- [SDL_GetMouseFocus](SDL_GetMouseFocus.html)
- [SDL_GetMouseNameForID](SDL_GetMouseNameForID.html)
- [SDL_GetMouseState](SDL_GetMouseState.html)
- [SDL_GetRelativeMouseState](SDL_GetRelativeMouseState.html)
- [SDL_GetWindowMouseGrab](SDL_GetWindowMouseGrab.html)
- [SDL_GetWindowMouseRect](SDL_GetWindowMouseRect.html)
- [SDL_GetWindowRelativeMouseMode](SDL_GetWindowRelativeMouseMode.html)
- [SDL_HasMouse](SDL_HasMouse.html)
- [SDL_HideCursor](SDL_HideCursor.html)
- [SDL_SetCursor](SDL_SetCursor.html)
- [SDL_SetRelativeMouseTransform](SDL_SetRelativeMouseTransform.html)
- [SDL_SetWindowMouseGrab](SDL_SetWindowMouseGrab.html)
- [SDL_SetWindowMouseRect](SDL_SetWindowMouseRect.html)
- [SDL_SetWindowRelativeMouseMode](SDL_SetWindowRelativeMouseMode.html)
- [SDL_ShowCursor](SDL_ShowCursor.html)
- [SDL_WarpMouseGlobal](SDL_WarpMouseGlobal.html)
- [SDL_WarpMouseInWindow](SDL_WarpMouseInWindow.html)

## Datatypes

- [SDL_Cursor](SDL_Cursor.html)
- [SDL_MouseButtonFlags](SDL_MouseButtonFlags.html)
- [SDL_MouseID](SDL_MouseID.html)
- [SDL_MouseMotionTransformCallback](SDL_MouseMotionTransformCallback.html)

## Structs

- [SDL_CursorFrameInfo](SDL_CursorFrameInfo.html)

## Enums

- [SDL_MouseWheelDirection](SDL_MouseWheelDirection.html)
- [SDL_SystemCursor](SDL_SystemCursor.html)

## Macros

- [SDL_TOUCH_MOUSEID](SDL_TOUCH_MOUSEID.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
