# Build and run
run:
    odin run ./src -out:hri.exe

# Build
build:
    odin build ./src -out:hri.exe

# Build debug
build-debug:
    odin build ./src -debug -out:./debug/hri.exe