# Changelog

## v1.2.0 (2025-10-26)

**Added**
- Option to use ground sprites that automatically match the underlying terrain type
- Export option to create a NewGRF overview as an HTML file or a Markdown formatted file
- Menu bar with some extended functionality (mostly laying the groundwork for additional features in future updates)

**Changed**
- Manage `LUA_PATH` via `package.path` in `main.lua` instead of in the batch file
- Removed leftover CLI commands from `START.bat`

**Fixed**
- Made module `create_image` global; it could not be called from `generate.lua`
- Replaced `require` with `dofile` for loading split source files


## v1.1.0 (2025-09-26)

**Added**
- Image preview on hover with individual ON/OFF settings  
- Option to compile GRF files directly from the app  

**Changed**
- Improved offsets in the purchase menu  
- Improved path handling  
- Refined layout and alignment of widgets  
- Added option to open the online manual if `Manual.html` is not found  
- Code cleanup and reorganization into separate files for better readability  

**Fixed**
- Snow sprites incorrectly copied image parameters from regular sprites  
- Typo in 1 × N template  
- Removed redundant 2 × 2 loop in `nml.lua`  
- Corrected `nearby_tile_height` range for objects larger than 9 × 9 tiles  

## v1.0.0 (2025-09-10)

Initial release.