Status: active
Owner: shell
Last-Reviewed: 2026-03-17
Canonical: yes

# Theme And Wallpaper Runtime

## What

This subsystem owns theme state, theme application, wallpaper setting, slideshow
control, and wallpaper sorting/runtime support.

## Why

Theme and wallpaper behavior are shell runtime concerns. They should be owned by
Zig runtime paths rather than scattered shell scripts.

## How

- theme state:
  [src/tools/theme_state.zig](/home/home/personal/wayspot/src/tools/theme_state.zig)
- theme apply:
  [src/tools/theme_apply.zig](/home/home/personal/wayspot/src/tools/theme_apply.zig)
- wallpaper runtime:
  [src/tools/wallpaper_runtime.zig](/home/home/personal/wayspot/src/tools/wallpaper_runtime.zig)
- slideshow control:
  [src/tools/slideshow_control.zig](/home/home/personal/wayspot/src/tools/slideshow_control.zig)
- wallpaper sorting:
  [src/tools/wallpaper_sorter.zig](/home/home/personal/wayspot/src/tools/wallpaper_sorter.zig)
- theme registry/families:
  [src/tools/theme_registry.zig](/home/home/personal/wayspot/src/tools/theme_registry.zig)

## When

Use this subsystem for:

- selecting and persisting a theme
- applying a theme to Hyprland/Waybar runtime files
- setting wallpaper on focused or all outputs
- slideshow lifecycle
- wallpaper library classification by theme family

## Where

- [src/tools/](/home/home/personal/wayspot/src/tools)
