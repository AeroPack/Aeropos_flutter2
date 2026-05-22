#!/bin/bash

# Ensure pngquant is installed before running
if ! command -v pngquant &> /dev/null; then
    echo "Error: pngquant is not installed. Run 'sudo apt install pngquant' first."
    exit 1
fi

# Create an output directory for the compressed images
OUTPUT_DIR="compressed_100kb"
mkdir -p "$OUTPUT_DIR"

echo "Starting compression..."
echo "-----------------------------------"

# Loop through all PNG files in the current directory
for img in *.png; do
    # Skip if no PNGs are found
    [ -e "$img" ] || continue 

    echo "Processing: $img"

    # Compress the image
    # --quality 65-80: Allows the tool to find the best balance of size and visual quality
    # --speed 1: Slowest processing speed for the highest possible visual quality
    # --skip-if-larger: Cancels if the resulting file is somehow larger than the original
    pngquant --quality=65-80 --speed 1 --skip-if-larger --output "$OUTPUT_DIR/$img" --force "$img"

    # Check if pngquant succeeded
    if [ $? -eq 0 ]; then
        orig_size=$(du -k "$img" | cut -f1)
        new_size=$(du -k "$OUTPUT_DIR/$img" | cut -f1)
        
        echo "  -> Success! Reduced from ${orig_size}KB to ${new_size}KB"
        
        # Warn if the file is still over 100KB
        if [ "$new_size" -gt 100 ]; then
            echo "  ⚠️ Warning: $img is still ${new_size}KB (over the 100KB target)."
        fi
    else
        echo "  -> Skipped (Original image is already highly optimized or below quality threshold)."
        # Copy the original file to the output directory so the set remains complete
        cp "$img" "$OUTPUT_DIR/$img"
    fi
done

echo "-----------------------------------"
echo "Done! Check the '$OUTPUT_DIR' folder for your optimized templates."
