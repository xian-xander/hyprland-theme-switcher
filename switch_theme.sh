#!/bin/bash

# ==============================================================================
# Hyprland Theme Switcher (Rofi + awww)
# ==============================================================================

# -- Configuration --
if [ -d "$HOME/Pictures" ]; then
    WALLPAPER_DIR="$HOME/Pictures/wallpapers"
elif [ -d "$HOME/Imagenes" ]; then
    WALLPAPER_DIR="$HOME/Imagenes/wallpapers"
else
    WALLPAPER_DIR="$HOME/Pictures/wallpapers"
fi
WALLPAPER_DAEMON="awww"
CACHE_DIR="$HOME/.cache/theme_thumbnails"
STATE_FILE="$HOME/.cache/current_theme"
ROFI_THEME="$HOME/.config/rofi/theme_switcher.rasi"
ROFI_COLORS="$HOME/.config/rofi/colors.rasi"

# -- Theme Definition --
# Format: "Name|rgba(active)|rgba(inactive)|wallpaper_file"
THEMES=(
    "Japan Night|rgba(4585abff)|rgba(01012bff)|japan_night.jpg"
    "Arch Hacker|rgba(00e5ffff)|rgba(002244ff)|arch_hacker.png"
    "Arch Gris|rgba(aaaaaaff)|rgba(333333ff)|arch_gris.png"
    "Pink Lake|rgba(ff66b2ff)|rgba(33001aff)|pink_lake.jpg"
    "Aboodi|rgba(5d8a82ff)|rgba(1a2226ff)|aboodi.jpg"
    "Chlouk|rgba(8c8279ff)|rgba(26221eff)|chlouk.jpg"
    "Israel Becker|rgba(517b96ff)|rgba(1e2226ff)|israel_becker.jpg"
    "John Callery|rgba(4a7852ff)|rgba(1e241dff)|john_callery.jpg"
    "Rinoadamo|rgba(3d542dff)|rgba(242123ff)|rinoadamo.jpg"
    "Steve 1|rgba(5a4278ff)|rgba(222222ff)|steve_1.jpg"
    "Steve 2|rgba(6b3d56ff)|rgba(26231eff)|steve_2.jpg"
    "Steve 3|rgba(757575ff)|rgba(1a1d1fff)|steve_3.jpg"
)

# Get old state for smooth transitions
OLD_THEME=""
if [[ -f "$STATE_FILE" ]]; then
    OLD_THEME=$(cat "$STATE_FILE")
fi

# ==============================================================================
# Step 1: Determine Selected Theme
# ==============================================================================
if [[ "$1" == "--restore" ]]; then
    # Restore mode: Read saved state without launching Rofi
    if [[ -n "$OLD_THEME" ]]; then
        SELECTED="$OLD_THEME"
    else
        SELECTED="${THEMES[0]%%|*}" # Default to first theme
    fi
else
    # Interactive mode: Generate thumbnails and launch Rofi
    mkdir -p "$CACHE_DIR"

    has_imagemagick=false
    if command -v magick &>/dev/null; then
        has_imagemagick=true
        im_cmd="magick"
    elif command -v convert &>/dev/null; then
        has_imagemagick=true
        im_cmd="convert"
    fi

    for entry in "${THEMES[@]}"; do
        file="${entry##*|}"
        src="$WALLPAPER_DIR/$file"
        thumb="$CACHE_DIR/$file"

        if [[ ! -f "$thumb" && "$has_imagemagick" == true && -f "$src" ]]; then
            "$im_cmd" "$src" -thumbnail 400x225 -quality 85 "$thumb" 2>/dev/null &
        fi
    done
    wait  # Wait for all thumbnails to generate in parallel

    if [[ "$has_imagemagick" == false ]]; then
        notify-send -u critical "Missing ImageMagick" "Install it with: yay -S imagemagick"
    fi

    # Build Rofi list
    ROFI_INPUT=""
    for entry in "${THEMES[@]}"; do
        IFS='|' read -r name _active _inactive file <<< "$entry"
        thumb="$CACHE_DIR/$file"

        if [[ -f "$thumb" ]]; then
            icon="$thumb"
        else
            icon="$WALLPAPER_DIR/$file"
        fi

        ROFI_INPUT+="${name}\0icon\x1f${icon}\n"
    done

    SELECTED=$(echo -en "$ROFI_INPUT" | rofi -dmenu -i -show-icons -theme "$ROFI_THEME" -p ">")
fi

[[ -z "$SELECTED" ]] && exit 0

# Save the current state for next login
echo "$SELECTED" > "$STATE_FILE"

# ==============================================================================
# Step 2: Apply selected theme
# ==============================================================================
for entry in "${THEMES[@]}"; do
    IFS='|' read -r name active_border inactive_border file <<< "$entry"

    [[ "$name" != "$SELECTED" ]] && continue

    wallpaper="$WALLPAPER_DIR/$file"

    # -- Update Rofi colors --
    active_hex="#${active_border:5:6}"
    inactive_hex="#${inactive_border:5:6}"
    mkdir -p "$(dirname "$ROFI_COLORS")"
    cat > "$ROFI_COLORS" <<EOF
* {
    active-border: ${active_hex};
    inactive-border: ${inactive_hex};
}
EOF

    # -- Apply border colors in Hyprland --
    hyprctl eval "hl.config({ general = { ['col.active_border'] = '${active_border}', ['col.inactive_border'] = '${inactive_border}' } })" >/dev/null 2>&1

    # -- Apply wallpaper --
    if [[ "$WALLPAPER_DAEMON" == "swaybg" ]]; then
        killall swaybg 2>/dev/null
        swaybg -i "$wallpaper" -m fill >/dev/null 2>&1 &
        disown
    elif [[ "$WALLPAPER_DAEMON" == "awww" ]]; then
        if [[ "$1" == "--restore" ]]; then
            # Para el inicio de sesión (--restore), usamos swaybg porque es instantáneo
            killall awww-daemon 2>/dev/null
            killall swaybg 2>/dev/null
            swaybg -i "$wallpaper" -m fill >/dev/null 2>&1 &
            disown
        else
            # Preparamos awww si no está corriendo
            if ! pgrep -x "awww-daemon" >/dev/null; then
                awww-daemon &
                sleep 0.5
                # Pre-cargamos la imagen ANTIGUA para que la transición no sea desde negro
                if [[ -n "$OLD_THEME" ]]; then
                    for old_entry in "${THEMES[@]}"; do
                        IFS='|' read -r old_name _ _ old_file <<< "$old_entry"
                        if [[ "$old_name" == "$OLD_THEME" ]]; then
                            awww img "$WALLPAPER_DIR/$old_file"
                            sleep 0.2
                            break
                        fi
                    done
                fi
                # Ahora que awww tiene la imagen vieja, matamos swaybg
                killall swaybg 2>/dev/null
            fi
            
            # Lanzamos la transición con awww hacia el nuevo wallpaper
            awww img "$wallpaper" --transition-type wipe --transition-angle 30 --transition-step 200 --transition-fps 60
        fi
    fi

    if [[ "$1" != "--restore" ]]; then
        notify-send -t 2000 "Hyprland" "Theme changed to: $name"
    fi
    break
done
