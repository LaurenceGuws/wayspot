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
- supported theme catalog:
  [src/tools/theme_catalog.zig](/home/home/personal/wayspot/src/tools/theme_catalog.zig)
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

Current scope note:

- theme persistence and theme application share one supported-theme authority
- theme apply is runtime-owned and generic to the app
- wallpaper runtime is currently explicit Hyprland/Hyprpaper integration
- slideshow lifecycle is daemon-owned in resident mode and controlled over IPC
- do not describe wallpaper control as backend-generic until a real wallpaper
  backend capability exists

## Where

- [src/tools/](/home/home/personal/wayspot/src/tools)

## Ownership Rule

Theme apply is a runtime operation. It should update runtime-owned config and
live runtime files only.

It must not:

- mutate an external dotfiles repo checkout as a side effect
- assume a repo-specific path like `~/personal/bash_engine`
- mix repo-sync concerns into the runtime hot path

Slideshow control must not:

- scrape process lists with `pgrep`
- kill broad process-name matches
- maintain a second process-lifecycle authority outside the resident daemon
