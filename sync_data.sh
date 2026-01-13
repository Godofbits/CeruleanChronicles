#!/bin/bash
################################################################################
# sync_data.sh
# Syncs monster and item data from iOS app to website
################################################################################

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths - iOS App
IOS_MONSTERS="/Users/carlvonhavighorst/Documents/workspace/Heroes of Lore/Heroes of Lore/Resources/Monsters"
IOS_MONSTER_IMAGES="/Users/carlvonhavighorst/Documents/workspace/Heroes of Lore/Heroes of Lore/Monsters.atlas"
IOS_ITEMS="/Users/carlvonhavighorst/Documents/workspace/CeruleanChronicles-Web/data/items"  # Exported by ItemExporter

# Paths - Website
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WEB_MONSTERS_DATA="$SCRIPT_DIR/data/monsters"
WEB_MONSTERS_IMAGES="$SCRIPT_DIR/images/monsters"
WEB_ITEMS_DATA="$SCRIPT_DIR/data/items"
WEB_ITEMS_IMAGES="$SCRIPT_DIR/images/items"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Cerulean Chronicles - Game Data Sync       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

################################################################################
# MONSTERS
################################################################################

echo -e "${BLUE}▶ Syncing Monsters${NC}"
echo ""

# Verify source directories exist
if [ ! -d "$IOS_MONSTERS" ]; then
    echo -e "${YELLOW}⚠ Error: iOS monster directory not found${NC}"
    echo "  Expected: $IOS_MONSTERS"
    exit 1
fi

if [ ! -d "$IOS_MONSTER_IMAGES" ]; then
    echo -e "${YELLOW}⚠ Error: iOS monster atlas directory not found${NC}"
    echo "  Expected: $IOS_MONSTER_IMAGES"
    exit 1
fi

# Clear old monster data
echo -e "${BLUE}→${NC} Clearing old monster data..."
rm -rf "$WEB_MONSTERS_DATA"
rm -rf "$WEB_MONSTERS_IMAGES"

# Create directories
echo -e "${BLUE}→${NC} Creating monster directories..."
mkdir -p "$WEB_MONSTERS_DATA"
mkdir -p "$WEB_MONSTERS_IMAGES"

# Sync monster JSON files (flatten directory structure)
echo -e "${BLUE}→${NC} Syncing monster JSON files..."
find "$IOS_MONSTERS" -name "*.json" -type f | while read file; do
    cp "$file" "$WEB_MONSTERS_DATA/"
done

# Count monster JSON files
monster_json_count=$(find "$WEB_MONSTERS_DATA" -name "*.json" -type f | wc -l | tr -d ' ')

# Sync monster images
echo -e "${BLUE}→${NC} Syncing monster images..."
monster_image_count=0
if ls "$IOS_MONSTER_IMAGES"/*.png 1> /dev/null 2>&1; then
    cp "$IOS_MONSTER_IMAGES"/*.png "$WEB_MONSTERS_IMAGES/"
    monster_image_count=$(ls "$WEB_MONSTERS_IMAGES"/*.png 2>/dev/null | wc -l | tr -d ' ')
fi

# Generate monster index.json
echo -e "${BLUE}→${NC} Generating monster index.json..."
cd "$WEB_MONSTERS_DATA"
ls *.json 2>/dev/null | sed 's/\.json$//' | sort | python3 -c "
import sys, json
items = [line.strip() for line in sys.stdin if line.strip()]
print(json.dumps(items, indent=2))
" > index.json

echo -e "${GREEN}✓ Monsters synced: ${monster_json_count} JSON, ${monster_image_count} images${NC}"
echo ""

################################################################################
# ITEMS
################################################################################

echo -e "${BLUE}▶ Syncing Items${NC}"
echo ""

# Check if items directory exists (created by ItemExporter)
if [ ! -d "$IOS_ITEMS" ]; then
    echo -e "${YELLOW}⚠ Warning: Items directory not found${NC}"
    echo "  Expected: $IOS_ITEMS"
    echo "  Run the iOS app to export items via ItemExporter"
    echo -e "${YELLOW}  Skipping item sync...${NC}"
    echo ""
    item_json_count=0
    item_image_count=0
else
    # Items are already exported to the website data directory by ItemExporter
    # Just count them
    item_json_count=$(find "$WEB_ITEMS_DATA" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [ "$item_json_count" -gt 0 ]; then
        echo -e "${GREEN}✓ Items already exported: ${item_json_count} JSON files${NC}"
    else
        echo -e "${YELLOW}⚠ No items found. Run the iOS app to export items.${NC}"
    fi
    echo ""
fi

# Sync item images from Assets.xcassets
IOS_ASSETS="/Users/carlvonhavighorst/Documents/workspace/Heroes of Lore/Heroes of Lore/Assets.xcassets"

if [ -d "$IOS_ASSETS" ]; then
    echo -e "${BLUE}→${NC} Syncing item images from Assets.xcassets..."

    # Clear old item images
    rm -rf "$WEB_ITEMS_IMAGES"
    mkdir -p "$WEB_ITEMS_IMAGES"

    # Copy images from all item categories
    cd "$IOS_ASSETS"
    find swords chest boots belts hands head pants potions rings scrolls staffs wands -name "*.png" -exec cp {} "$WEB_ITEMS_IMAGES/" \; 2>/dev/null

    # Also copy from Equipment and WorldItems atlases
    if [ -d "../Atlases/Equipment.atlas" ]; then
        cp ../Atlases/Equipment.atlas/*.png "$WEB_ITEMS_IMAGES/" 2>/dev/null || true
    fi

    if [ -d "../Atlases/WorldItems.atlas" ]; then
        cp ../Atlases/WorldItems.atlas/*.png "$WEB_ITEMS_IMAGES/" 2>/dev/null || true
    fi

    item_image_count=$(ls "$WEB_ITEMS_IMAGES"/*.png 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✓ Item images synced: ${item_image_count} images${NC}"
    echo ""
else
    echo -e "${YELLOW}⚠ Warning: Assets.xcassets not found${NC}"
    item_image_count=0
    echo ""
fi

################################################################################
# SUMMARY
################################################################################

echo -e "${GREEN}✓ Sync complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "  Monsters:  ${GREEN}${monster_json_count} JSON${NC}, ${GREEN}${monster_image_count} images${NC}"
echo -e "  Items:     ${GREEN}${item_json_count} JSON${NC}, ${GREEN}${item_image_count} images${NC}"
echo ""

# Check for monster mismatch
if [ "$monster_json_count" != "$monster_image_count" ]; then
    echo -e "${YELLOW}⚠ Warning: Monster JSON count ($monster_json_count) ≠ Image count ($monster_image_count)${NC}"
    echo "  Some monsters may be missing images"
    echo ""
fi

echo -e "${GREEN}Ready for local testing!${NC}"
echo ""
