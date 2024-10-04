#!/bin/bash

set -e

ORIGINAL_DIR=$(pwd)
REPO_URL="https://gitlab.com/astra-language/vscode-language-astra.git"
BUNDLE_NAME="astra.tmbundle"
TEMP_DIR=$(mktemp -d)
UUID=$(uuidgen)

git clone "$REPO_URL" "$TEMP_DIR"
cd "$TEMP_DIR"

# Install jq for JSON parsing
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
fi

# **Fix the 'path' in 'package.json' to match the actual directory**
sed -i 's/"path": ".\/Syntaxes\//"path": ".\/syntaxes\//g' package.json

# Get grammar file path from package.json
GRAMMAR_PATH=$(jq -r '.contributes.grammars[0].path' package.json)

mkdir -p "$BUNDLE_NAME/Syntaxes"
cp "$GRAMMAR_PATH" "$BUNDLE_NAME/Syntaxes/"

FILENAME=$(basename "$GRAMMAR_PATH")
EXT="${FILENAME##*.}"
BASENAME="${FILENAME%%.*}"

# Convert JSON grammar to plist
if [ "$EXT" == "json" ]; then
    echo "Converting JSON grammar to plist format..."

    cd "$BUNDLE_NAME/Syntaxes"

    npm init -y > /dev/null 2>&1
    npm install plist
    # Convert JSON to plist 
    node -e "
    const fs = require('fs');
    const plist = require('plist');
    const json = fs.readFileSync('$FILENAME', 'utf8');
    const obj = JSON.parse(json);

    obj['fileTypes'] = ['astra'];

    const xml = plist.build(obj);
    fs.writeFileSync('${BASENAME}.tmLanguage', xml);"

    rm "$FILENAME"

    rm -rf node_modules package.json package-lock.json
    cd ../../
fi

# Create info.plist
cat > "$BUNDLE_NAME/info.plist" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
   "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
   <key>CFBundleIdentifier</key>
   <string>com.astralanguage</string>
   <key>CFBundleName</key>
   <string>ASTRA</string>
   <key>CFBundleVersion</key>
   <string>1.0</string>
   <key>UUID</key>
   <string>$UUID</string>
</dict>
</plist>
EOL

if [ -n "$GITHUB_WORKSPACE" ]; then
    mv "$BUNDLE_NAME" "$GITHUB_WORKSPACE/"
else
    mv "$BUNDLE_NAME" "$ORIGINAL_DIR/"
fi

# Clean up
rm -rf "$TEMP_DIR"

echo "TextMate bundle created successfully."

