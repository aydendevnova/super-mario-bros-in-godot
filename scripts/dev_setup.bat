@echo off
echo Marking generated assets as assume-unchanged...
for /f "tokens=*" %%i in ('git ls-files assets/textures/ assets/music/ assets/sfx/') do (
    git update-index --assume-unchanged "%%i"
)
echo Done. Local asset generation will not appear in git status.
echo Run '_gen_assets/main.py sprites' to generate real textures for editor preview.
