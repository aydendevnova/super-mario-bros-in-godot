#!/bin/bash
echo "Marking generated assets as assume-unchanged..."
git ls-files assets/textures/ \
  | xargs git update-index --assume-unchanged
echo "Done. Local asset generation will not appear in git status."
echo "Run 'python3 _gen_assets/main.py sprites' for editor preview textures."
