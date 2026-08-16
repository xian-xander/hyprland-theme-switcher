#!/bin/bash

# ==============================================================================
# Hyprland Theme Switcher — Installer
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   Hyprland Theme Switcher — Installer    ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ==============================================================================
# Step 1: Check dependencies
# ==============================================================================
echo -e "${YELLOW}[1/5]${NC} Checking dependencies..."

DEPS=("rofi" "magick|convert" "awww" "notify-send" "hyprctl" "matugen")
NAMES=("rofi-wayland" "imagemagick" "awww" "libnotify" "hyprland" "matugen-bin")
MISSING=()

for i in "${!DEPS[@]}"; do
    dep="${DEPS[$i]}"
    found=false

    IFS='|' read -ra alternatives <<< "$dep"
    for alt in "${alternatives[@]}"; do
        if command -v "$alt" &>/dev/null; then
            found=true
            break
        fi
    done

    if [[ "$found" == false ]]; then
        MISSING+=("${NAMES[$i]}")
        echo -e "  ${RED}✗${NC} ${NAMES[$i]} not found"
    else
        echo -e "  ${GREEN}✓${NC} ${NAMES[$i]}"
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Missing dependencies. Do you want to install them automatically? (y/n)${NC}"
    read -r respuesta
    if [[ "$respuesta" == "y" || "$respuesta" == "Y" || "$respuesta" == "yes" ]]; then
        echo -e "${CYAN}Installing: ${MISSING[*]}${NC}"
        yay -S --needed "${MISSING[@]}"
    else
        echo -e "${RED}Please install them manually before continuing:${NC}"
        echo "  yay -S ${MISSING[*]}"
        exit 1
    fi
fi

echo ""

# ==============================================================================
# Step 2: Copy Rofi configuration
# ==============================================================================
echo -e "${YELLOW}[2/5]${NC} Installing Rofi theme..."

ROFI_DIR="$HOME/.config/rofi"
mkdir -p "$ROFI_DIR"

cp "$SCRIPT_DIR/rofi/colors.rasi" "$ROFI_DIR/colors.rasi"
cp "$SCRIPT_DIR/rofi/theme_switcher.rasi" "$ROFI_DIR/theme_switcher.rasi"

echo -e "  ${GREEN}✓${NC} Files copied to $ROFI_DIR"
echo ""

# ==============================================================================
# Step 3: Install Matugen config and main script
# ==============================================================================
echo -e "${YELLOW}[3/5]${NC} Installing configs and main script..."

MATUGEN_DIR="$HOME/.config/matugen"
mkdir -p "$MATUGEN_DIR/templates"
cp -r "$SCRIPT_DIR/matugen/templates/"* "$MATUGEN_DIR/templates/" 2>/dev/null || true

# Generate portable config.toml
sed "s|/home/jorge|$HOME|g" "$SCRIPT_DIR/matugen/config.toml" > "$MATUGEN_DIR/config.toml"

echo -e "  ${GREEN}✓${NC} Matugen templates copied to $MATUGEN_DIR"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

cp "$SCRIPT_DIR/switch_theme.sh" "$BIN_DIR/switch_theme.sh"
chmod +x "$BIN_DIR/switch_theme.sh"

echo -e "  ${GREEN}✓${NC} switch_theme.sh installed in $BIN_DIR"
echo ""

# ==============================================================================
# Step 4: Copy wallpapers
# ==============================================================================
echo -e "${YELLOW}[4/5]${NC} Installing wallpapers..."

# NOTE: Also updated to English Pictures dir instead of Imagenes just in case, but keeping standard xdg-user-dirs fallback
if [ -d "$HOME/Pictures" ]; then
    WALL_DIR="$HOME/Pictures/wallpapers"
elif [ -d "$HOME/Imagenes" ]; then
    WALL_DIR="$HOME/Imagenes/wallpapers"
else
    WALL_DIR="$HOME/Pictures/wallpapers" # Default
fi
mkdir -p "$WALL_DIR"

count=0
for img in "$SCRIPT_DIR/wallpapers/"*.{jpg,png,jpeg,webp}; do
    [[ -f "$img" ]] || continue
    base="$(basename "$img")"
    if [[ ! -f "$WALL_DIR/$base" ]]; then
        cp "$img" "$WALL_DIR/"
        count=$((count + 1))
    fi
done

echo -e "  ${GREEN}✓${NC} $count new wallpapers copied to $WALL_DIR"
echo ""

# ==============================================================================
# Step 5: Generate thumbnail cache
# ==============================================================================
echo -e "${YELLOW}[5/5]${NC} Generating thumbnail cache..."

CACHE_DIR="$HOME/.cache/theme_thumbnails"
mkdir -p "$CACHE_DIR"

if command -v magick &>/dev/null; then
    im_cmd="magick"
elif command -v convert &>/dev/null; then
    im_cmd="convert"
else
    im_cmd=""
fi

if [[ -n "$im_cmd" ]]; then
    thumb_count=0
    for img in "$WALL_DIR"/*.{jpg,png,jpeg,webp}; do
        [[ -f "$img" ]] || continue
        base="$(basename "$img")"
        thumb="$CACHE_DIR/$base"
        if [[ ! -f "$thumb" ]]; then
            "$im_cmd" "$img" -thumbnail 400x225 -quality 85 "$thumb" 2>/dev/null &
            thumb_count=$((thumb_count + 1))
        fi
    done
    wait
    echo -e "  ${GREEN}✓${NC} $thumb_count thumbnails generated"
else
    echo -e "  ${YELLOW}!${NC} ImageMagick not found, thumbnail generation skipped"
fi

echo ""

# ==============================================================================
# Step 6: Inject into Hyprland Config
# ==============================================================================
echo -e "${YELLOW}[6/6]${NC} Configuring Hyprland..."

HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

if [[ -f "$HYPR_LUA" ]]; then
    if ! grep -q "switch_theme.sh" "$HYPR_LUA"; then
        echo "" >> "$HYPR_LUA"
        echo "-- Hyprland Theme Switcher" >> "$HYPR_LUA"
        echo 'hl.on("hyprland.start", function()' >> "$HYPR_LUA"
        echo '    hl.exec_cmd("bash ~/.local/bin/switch_theme.sh --restore &")' >> "$HYPR_LUA"
        echo 'end)' >> "$HYPR_LUA"
        echo 'hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("bash ~/.local/bin/switch_theme.sh"))' >> "$HYPR_LUA"
        echo -e "  ${GREEN}✓${NC} Configuration automatically added to hyprland.lua"
    else
        echo -e "  ${YELLOW}✓${NC} Configuration already exists in hyprland.lua"
    fi
elif [[ -f "$HYPR_CONF" ]]; then
    if ! grep -q "switch_theme.sh" "$HYPR_CONF"; then
        echo "" >> "$HYPR_CONF"
        echo "# Hyprland Theme Switcher" >> "$HYPR_CONF"
        echo "exec-once = bash ~/.local/bin/switch_theme.sh --restore" >> "$HYPR_CONF"
        echo 'bind = SUPER, T, exec, bash ~/.local/bin/switch_theme.sh' >> "$HYPR_CONF"
        echo -e "  ${GREEN}✓${NC} Configuration automatically added to hyprland.conf"
    else
        echo -e "  ${YELLOW}✓${NC} Configuration already exists in hyprland.conf"
    fi
else
    echo -e "  ${RED}!${NC} Hyprland config not found. Please add the keybind manually."
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Installation completed!             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "Reload Hyprland and press ${YELLOW}SUPER + T${NC} to start."
echo ""
