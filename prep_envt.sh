#!/bin/bash

RECIPES_PATH="$(pwd)/Tools/bin/recipes"
# Add recipes which contains things like mitigate all
if [[ "$PATH" != *"$RECIPES_PATH"* ]]; then
    # PATH="$PATH:$(pwd)/Tools/bin/recipes"
    PATH=$PATH:$RECIPES_PATH
fi

# Add shortcut script
SHORTCUT_PATH="$(pwd)/Tools/bin/shortcut"
if [[ "$PATH" != *"$SHORTCUT_PATH"* ]]; then
    PATH=$PATH:$SHORTCUT_PATH
fi

# Add symlib LD_LIBRARY_PATH
SYM_LIB_PATH="$(pwd)/Symlib/dynam_build"
if [[ "$LD_LIBRARY_PATH" != *"$SYM_LIB_PATH"* ]]; then
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SYM_LIB_PATH
fi

# Export path
export PATH
export LD_LIBRARY_PATH