#!/bin/bash

# TODO: Potential issue, you may match the string with extra path info
# before or after it. Then not update as you expect. Only likely if
# you're running this multiple times. Only expected to run once.
# This bug occurs when you take away, not add to the path.

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

# Add symlib LD_LIBRARY_PATH
SYM_TOOLS_PATH="$(pwd)/Tools/lib"
if [[ "$LD_LIBRARY_PATH" != *"$SYM_TOOLS_PATH"* ]]; then
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SYM_TOOLS_PATH
fi

# Export path
export PATH
export LD_LIBRARY_PATH

