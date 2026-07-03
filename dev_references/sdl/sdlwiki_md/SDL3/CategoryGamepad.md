# CategoryGamepad

SDL provides a low-level joystick API, which just treats joysticks as an
arbitrary pile of buttons, axes, and hat switches. If you're planning to
write your own control configuration screen, this can give you a lot of
flexibility, but that's a lot of work, and most things that we consider
"joysticks" now are actually console-style gamepads. So SDL provides the
gamepad API on top of the lower-level joystick functionality.

The difference between a joystick and a gamepad is that a gamepad tells
you *where* a button or axis is on the device. You don't speak to
gamepads in terms of arbitrary numbers like "button 3" or "axis 2" but
in standard locations: the d-pad, the shoulder buttons, triggers,
A/B/X/Y (or X/O/Square/Triangle, if you will).

One turns a joystick into a gamepad by providing a magic configuration
string, which tells SDL the details of a specific device: when you see
this specific hardware, if button 2 gets pressed, this is actually D-Pad
Up, etc.

SDL has many popular controllers configured out of the box, and users
can add their own controller details through an environment variable if
it's otherwise unknown to SDL.

In order to use these functions, [SDL_Init](SDL_Init.html)() must have
been called with the [SDL_INIT_GAMEPAD](SDL_INIT_GAMEPAD.html) flag.
This causes SDL to scan the system for gamepads, and load appropriate
drivers.

If you're using SDL gamepad support in a Steam game, you must call
SteamAPI_InitEx() before calling [SDL_Init](SDL_Init.html)().

If you would like to receive gamepad updates while the application is in
the background, you should set the following hint before calling
[SDL_Init](SDL_Init.html)():
[SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS](SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS.html)

Gamepads support various optional features such as rumble, color LEDs,
touchpad, gyro, etc. The support for these features varies depending on
the controller and OS support available. You can check for LED and
rumble capabilities at runtime by calling
[SDL_GetGamepadProperties](SDL_GetGamepadProperties.html)() and checking
the various capability properties. You can check for touchpad by calling
[SDL_GetNumGamepadTouchpads](SDL_GetNumGamepadTouchpads.html)() and
check for gyro and accelerometer by calling
[SDL_GamepadHasSensor](SDL_GamepadHasSensor.html)().

By default SDL will try to use the most capable driver available, but
you can tune which OS drivers to use with the various joystick hints in
[SDL_hints](SDL_hints.html).h.

Your application should always support gamepad hotplugging. On some
platforms like Xbox, Steam Deck, etc., this is a requirement for
certification. On other platforms, like macOS and Windows when using
Windows.Gaming.Input, controllers may not be available at startup and
will come in at some point after you've started processing events.

## Functions

- [SDL_AddGamepadMapping](SDL_AddGamepadMapping.html)
- [SDL_AddGamepadMappingsFromFile](SDL_AddGamepadMappingsFromFile.html)
- [SDL_AddGamepadMappingsFromIO](SDL_AddGamepadMappingsFromIO.html)
- [SDL_CloseGamepad](SDL_CloseGamepad.html)
- [SDL_GamepadConnected](SDL_GamepadConnected.html)
- [SDL_GamepadEventsEnabled](SDL_GamepadEventsEnabled.html)
- [SDL_GamepadHasAxis](SDL_GamepadHasAxis.html)
- [SDL_GamepadHasButton](SDL_GamepadHasButton.html)
- [SDL_GamepadHasSensor](SDL_GamepadHasSensor.html)
- [SDL_GamepadSensorEnabled](SDL_GamepadSensorEnabled.html)
- [SDL_GetGamepadAppleSFSymbolsNameForAxis](SDL_GetGamepadAppleSFSymbolsNameForAxis.html)
- [SDL_GetGamepadAppleSFSymbolsNameForButton](SDL_GetGamepadAppleSFSymbolsNameForButton.html)
- [SDL_GetGamepadAxis](SDL_GetGamepadAxis.html)
- [SDL_GetGamepadAxisFromString](SDL_GetGamepadAxisFromString.html)
- [SDL_GetGamepadBindings](SDL_GetGamepadBindings.html)
- [SDL_GetGamepadButton](SDL_GetGamepadButton.html)
- [SDL_GetGamepadButtonFromString](SDL_GetGamepadButtonFromString.html)
- [SDL_GetGamepadButtonLabel](SDL_GetGamepadButtonLabel.html)
- [SDL_GetGamepadButtonLabelForType](SDL_GetGamepadButtonLabelForType.html)
- [SDL_GetGamepadConnectionState](SDL_GetGamepadConnectionState.html)
- [SDL_GetGamepadFirmwareVersion](SDL_GetGamepadFirmwareVersion.html)
- [SDL_GetGamepadFromID](SDL_GetGamepadFromID.html)
- [SDL_GetGamepadFromPlayerIndex](SDL_GetGamepadFromPlayerIndex.html)
- [SDL_GetGamepadGUIDForID](SDL_GetGamepadGUIDForID.html)
- [SDL_GetGamepadID](SDL_GetGamepadID.html)
- [SDL_GetGamepadJoystick](SDL_GetGamepadJoystick.html)
- [SDL_GetGamepadMapping](SDL_GetGamepadMapping.html)
- [SDL_GetGamepadMappingForGUID](SDL_GetGamepadMappingForGUID.html)
- [SDL_GetGamepadMappingForID](SDL_GetGamepadMappingForID.html)
- [SDL_GetGamepadMappings](SDL_GetGamepadMappings.html)
- [SDL_GetGamepadName](SDL_GetGamepadName.html)
- [SDL_GetGamepadNameForID](SDL_GetGamepadNameForID.html)
- [SDL_GetGamepadPath](SDL_GetGamepadPath.html)
- [SDL_GetGamepadPathForID](SDL_GetGamepadPathForID.html)
- [SDL_GetGamepadPlayerIndex](SDL_GetGamepadPlayerIndex.html)
- [SDL_GetGamepadPlayerIndexForID](SDL_GetGamepadPlayerIndexForID.html)
- [SDL_GetGamepadPowerInfo](SDL_GetGamepadPowerInfo.html)
- [SDL_GetGamepadProduct](SDL_GetGamepadProduct.html)
- [SDL_GetGamepadProductForID](SDL_GetGamepadProductForID.html)
- [SDL_GetGamepadProductVersion](SDL_GetGamepadProductVersion.html)
- [SDL_GetGamepadProductVersionForID](SDL_GetGamepadProductVersionForID.html)
- [SDL_GetGamepadProperties](SDL_GetGamepadProperties.html)
- [SDL_GetGamepads](SDL_GetGamepads.html)
- [SDL_GetGamepadSensorData](SDL_GetGamepadSensorData.html)
- [SDL_GetGamepadSensorDataRate](SDL_GetGamepadSensorDataRate.html)
- [SDL_GetGamepadSerial](SDL_GetGamepadSerial.html)
- [SDL_GetGamepadSteamHandle](SDL_GetGamepadSteamHandle.html)
- [SDL_GetGamepadStringForAxis](SDL_GetGamepadStringForAxis.html)
- [SDL_GetGamepadStringForButton](SDL_GetGamepadStringForButton.html)
- [SDL_GetGamepadStringForType](SDL_GetGamepadStringForType.html)
- [SDL_GetGamepadTouchpadFinger](SDL_GetGamepadTouchpadFinger.html)
- [SDL_GetGamepadType](SDL_GetGamepadType.html)
- [SDL_GetGamepadTypeForID](SDL_GetGamepadTypeForID.html)
- [SDL_GetGamepadTypeFromString](SDL_GetGamepadTypeFromString.html)
- [SDL_GetGamepadVendor](SDL_GetGamepadVendor.html)
- [SDL_GetGamepadVendorForID](SDL_GetGamepadVendorForID.html)
- [SDL_GetNumGamepadTouchpadFingers](SDL_GetNumGamepadTouchpadFingers.html)
- [SDL_GetNumGamepadTouchpads](SDL_GetNumGamepadTouchpads.html)
- [SDL_GetRealGamepadType](SDL_GetRealGamepadType.html)
- [SDL_GetRealGamepadTypeForID](SDL_GetRealGamepadTypeForID.html)
- [SDL_HasGamepad](SDL_HasGamepad.html)
- [SDL_IsGamepad](SDL_IsGamepad.html)
- [SDL_OpenGamepad](SDL_OpenGamepad.html)
- [SDL_ReloadGamepadMappings](SDL_ReloadGamepadMappings.html)
- [SDL_RumbleGamepad](SDL_RumbleGamepad.html)
- [SDL_RumbleGamepadTriggers](SDL_RumbleGamepadTriggers.html)
- [SDL_SendGamepadEffect](SDL_SendGamepadEffect.html)
- [SDL_SetGamepadEventsEnabled](SDL_SetGamepadEventsEnabled.html)
- [SDL_SetGamepadLED](SDL_SetGamepadLED.html)
- [SDL_SetGamepadMapping](SDL_SetGamepadMapping.html)
- [SDL_SetGamepadPlayerIndex](SDL_SetGamepadPlayerIndex.html)
- [SDL_SetGamepadSensorEnabled](SDL_SetGamepadSensorEnabled.html)
- [SDL_UpdateGamepads](SDL_UpdateGamepads.html)

## Datatypes

- [SDL_Gamepad](SDL_Gamepad.html)

## Structs

- [SDL_GamepadBinding](SDL_GamepadBinding.html)

## Enums

- [SDL_GamepadAxis](SDL_GamepadAxis.html)
- [SDL_GamepadBindingType](SDL_GamepadBindingType.html)
- [SDL_GamepadButton](SDL_GamepadButton.html)
- [SDL_GamepadButtonLabel](SDL_GamepadButtonLabel.html)
- [SDL_GamepadType](SDL_GamepadType.html)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
