#!/bin/bash

# ==============================================================================
# Hyprland Theme Switcher (Rofi + awww + Matugen)
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
STATE_FILE="$HOME/.cache/current_wallpaper"
ROFI_THEME="$HOME/.config/rofi/theme_switcher.rasi"
MATUGEN_COLORS="$HOME/.cache/theme_thumbnails/matugen_colors.sh"

# Get old state for smooth transitions
OLD_WALLPAPER=""
if [[ -f "$STATE_FILE" ]]; then
    OLD_WALLPAPER=$(cat "$STATE_FILE")
fi

# ==============================================================================
# Step 1: Determine Selected Wallpaper
# ==============================================================================
if [[ "$1" == "--restore" ]]; then
    # Restore mode: Read saved state without launching Rofi
    if [[ -n "$OLD_WALLPAPER" && -f "$OLD_WALLPAPER" ]]; then
        wallpaper="$OLD_WALLPAPER"
    else
        # Default to first wallpaper in directory
        wallpaper=$(find "$WALLPAPER_DIR" -type f \( -iname \*.jpg -o -iname \*.png -o -iname \*.webp \) | head -n 1)
        [[ -z "$wallpaper" ]] && exit 1
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

    ROFI_INPUT=""
    for img in "$WALLPAPER_DIR"/*.{jpg,png,jpeg,webp}; do
        [[ -f "$img" ]] || continue
        
        file="$(basename "$img")"
        name="${file%.*}" # Remove extension for display name
        # Capitalize and replace underscores with spaces
        name="$(echo "$name" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')"
        
        thumb="$CACHE_DIR/$file"

        if [[ ! -f "$thumb" && "$has_imagemagick" == true ]]; then
            "$im_cmd" "$img" -thumbnail 400x225 -quality 85 "$thumb" 2>/dev/null &
        fi
        
        if [[ -f "$thumb" ]]; then
            icon="$thumb"
        else
            icon="$img"
        fi

        ROFI_INPUT+="${name}\0icon\x1f${icon}\0info\x1f${img}\n"
    done
    wait  # Wait for all thumbnails to generate in parallel

    if [[ "$has_imagemagick" == false ]]; then
        notify-send -u critical "Missing ImageMagick" "Install it with: yay -S imagemagick"
    fi

    # Launch Rofi and extract the selected file path (using info field)
    # Note: Rofi returns the 'info' field if requested, but standard dmenu just returns the name.
    # To reliably map back to the file without complex Rofi formatting, we'll parse the output.
    # Since we can't easily extract info from simple rofi dmenu, we map the name back:
    
    SELECTED_NAME=$(echo -en "$ROFI_INPUT" | rofi -dmenu -i -show-icons -theme "$ROFI_THEME" -p ">")
    [[ -z "$SELECTED_NAME" ]] && exit 0

    # Find the corresponding file
    wallpaper=""
    for img in "$WALLPAPER_DIR"/*.{jpg,png,jpeg,webp}; do
        [[ -f "$img" ]] || continue
        file="$(basename "$img")"
        name="${file%.*}"
        name="$(echo "$name" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')"
        if [[ "$name" == "$SELECTED_NAME" ]]; then
            wallpaper="$img"
            break
        fi
    done
    
    [[ -z "$wallpaper" ]] && exit 1
fi

# Save the current state for next login
echo "$wallpaper" > "$STATE_FILE"

# ==============================================================================
# Step 2: Generate Colors with Matugen
# ==============================================================================
if command -v matugen &>/dev/null; then
    matugen image "$wallpaper" --prefer darkness
else
    notify-send -u critical "Missing Matugen" "Please install matugen to generate dynamic colors"
    # Fallback default colors if Matugen is missing
    mkdir -p "$(dirname "$MATUGEN_COLORS")"
    echo 'ACTIVE_BORDER="rgba(00e5ffff)"' > "$MATUGEN_COLORS"
    echo 'INACTIVE_BORDER="rgba(002244ff)"' >> "$MATUGEN_COLORS"
fi

# ==============================================================================
# Step 3: Apply Theme
# ==============================================================================

# -- Apply border colors in Hyprland --
if [[ -f "$MATUGEN_COLORS" ]]; then
    source "$MATUGEN_COLORS"
    
    # Apply to standard hyprland.conf setups
    hyprctl keyword general:col.active_border "rgba(${ACTIVE_BORDER:1}ff)" >/dev/null 2>&1
    hyprctl keyword general:col.inactive_border "rgba(${INACTIVE_BORDER:1}aa)" >/dev/null 2>&1
    
    # Apply to hyprland-lua setups (silently fails if plugin isn't installed)
    hyprctl eval "hl.config({ general = { ['col.active_border'] = 'rgba(${ACTIVE_BORDER:1}ff)', ['col.inactive_border'] = 'rgba(${INACTIVE_BORDER:1}aa)' } })" >/dev/null 2>&1
fi

# -- Apply Kitty colors --
killall -USR1 kitty 2>/dev/null

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
            if [[ -n "$OLD_WALLPAPER" && -f "$OLD_WALLPAPER" ]]; then
                awww img "$OLD_WALLPAPER"
                sleep 0.2
            fi
            # Ahora que awww tiene la imagen vieja, matamos swaybg
            killall swaybg 2>/dev/null
        fi
        
        # Lanzamos la transición con awww hacia el nuevo wallpaper
        awww img "$wallpaper" --transition-type wipe --transition-angle 30 --transition-step 200 --transition-fps 60
    fi
fi

if [[ "$1" != "--restore" ]]; then
    notify-send -t 2000 "Theme Switcher" "Applied colors for $(basename "$wallpaper")"
fi
