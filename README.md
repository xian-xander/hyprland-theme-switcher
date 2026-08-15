# Hyprland Theme Switcher

A visual theme switcher for **Hyprland** with wallpaper previews using **Rofi**, transition animations with **awww**, and dynamic colors that adapt to each wallpaper.

![Preview](preview.png)

## Features

- **Visual selector** with wallpaper thumbnails in a 4x2 grid
- **Dynamic colors** — window borders adapt automatically to each background
- **Thumbnail cache** — parallel generation with ImageMagick for instant loading
- **Smooth transition animations** when changing backgrounds (wipe with awww)
- **Hyprland integration** — changes active/inactive borders on the fly
- **12 wallpapers included** ready to use

## Dependencies

| Package | Function | Installation |
|---------|----------|--------------|
| `rofi-wayland` | Theme selection menu | `yay -S rofi-wayland` |
| `imagemagick` | Thumbnail generation for cache | `yay -S imagemagick` |
| `awww` | Wallpaper transition animations | `yay -S awww` |
| `hyprland` | Wayland compositor | `yay -S hyprland` |
| `libnotify` | Theme change notifications | `yay -S libnotify` |

## Project Structure

```
hyprland-theme-switcher/
├── install.sh                    # Automatic installation script
├── switch_theme.sh               # Main theme switcher script
├── rofi/
│   ├── colors.rasi               # Dynamic colors (updates automatically)
│   └── theme_switcher.rasi       # Visual theme for the wallpaper selector
├── wallpapers/                   # 12 included wallpapers
│   ├── japan_night.jpg
│   ├── arch_hacker.png
│   ├── arch_gris.png
│   ├── pink_lake.jpg
│   └── ... (8 more)
└── README.md
```

## Installation

### Automatic Installation

```bash
git clone https://github.com/xian-xander/hyprland-theme-switcher
cd hyprland-theme-switcher
chmod +x install.sh
./install.sh
```

### Manual Installation

1. Install dependencies:
```bash
yay -S rofi-wayland imagemagick awww libnotify
```

2. Copy Rofi files:
```bash
mkdir -p ~/.config/rofi
cp rofi/colors.rasi ~/.config/rofi/
cp rofi/theme_switcher.rasi ~/.config/rofi/
```

3. Copy the main script:
```bash
mkdir -p ~/.local/bin
cp switch_theme.sh ~/.local/bin/switch_theme.sh
chmod +x ~/.local/bin/switch_theme.sh
```

4. Copy the wallpapers:
```bash
mkdir -p ~/Pictures/wallpapers
cp wallpapers/* ~/Pictures/wallpapers/
```

5. Add this keybind to your Hyprland configuration (`hyprland.lua`):
```lua
-- Theme selector
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("bash ~/.local/bin/switch_theme.sh"))
```

## Usage

| Shortcut | Action |
|----------|--------|
| `SUPER + T` | Open theme/wallpaper selector |

## Customization

### Adding new themes

1. Copy your wallpaper to `~/Pictures/wallpapers/`
2. Edit the `THEMES` array in `switch_theme.sh`:

```bash
THEMES=(
    "Theme Name|rgba(ACTIVECOLORff)|rgba(INACTIVECOLORff)|filename.jpg"
)
```

- **Field 1**: Name that will appear in the menu
- **Field 2**: Active window border color (`rgba(RRGGBBff)` format)
- **Field 3**: Inactive window border color (`rgba(RRGGBBff)` format)
- **Field 4**: Wallpaper filename

### Changing the wallpaper daemon

```bash
WALLPAPER_DAEMON="awww"    # With transition animations
WALLPAPER_DAEMON="swaybg"  # Without animations (lighter)
```

### Regenerating thumbnails

If you add new wallpapers, clear the cache to regenerate them:
```bash
rm -rf ~/.cache/theme_thumbnails
```

## License

MIT
