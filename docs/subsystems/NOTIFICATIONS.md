Status: active
Owner: notifications
Last-Reviewed: 2026-03-17
Canonical: yes

# Notifications

## What

The notifications subsystem owns notification ingestion, runtime state, daemon
behavior, and popup/history surfaces.

## Why

Notifications are a first-class shell concern and need lifecycle ownership
outside of the launcher widget tree.

## How

- module exports:
  [src/notifications/mod.zig](/home/home/personal/wayspot/src/notifications/mod.zig)
- state/runtime/dbus files:
  [src/notifications/](/home/home/personal/wayspot/src/notifications)
- GTK integration:
  [src/ui/gtk/shell_notifications.zig](/home/home/personal/wayspot/src/ui/gtk/shell_notifications.zig),
  [src/ui/gtk/shell_notifications_popup.zig](/home/home/personal/wayspot/src/ui/gtk/shell_notifications_popup.zig)

## When

Notification delivery, popup policies, DBus handling, and history behavior
should be changed here rather than being bolted into launcher search code.

## Where

- [src/notifications/](/home/home/personal/wayspot/src/notifications)
