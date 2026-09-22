# Vigilante 8 Level Compiler & Decompiler (.EXP)

A standalone Delphi 7 utility designed to extract, analyze, and rebuild the proprietary level data archives (`*.EXP`) used by the **Vigilante 8** engine on the original PlayStation (PS1).

## Features
- **Strict Stream-Based Processing:** Uses `TFileStream` architecture for stable byte-perfect operations without risking local buffer overflows.
- **Dynamic Header & Tag Detection:** Correctly manages shifting block structures, including the initial 8-byte global definition tag and standard consecutive 4-byte identifiers.
- **Special BSP Block Protection:** Detects and flags nested collision/geometry trees (`BSP ` blocks) to maintain precise memory tracking and prevent file indexing alignment shifts during unpack.
- **Big-Endian Handling:** Implements an internal 32-bit register shifter (`Swap32`) to translate Big-Endian console values into native Windows integer allocations on the fly.
- **Automatic Padding & Realignment:** Evaluates unaligned block data using modulo operations (`mod 2`) to seamlessly strip or inject null padding bytes based on the PS1 architecture memory restrictions.
- **Manifest-Driven Rebuilding:** Outputs an automated packing blueprint (`!files.cfg`) to ensure the compiler stacks data sequences back into an authentic `.EXP` mirror file.

## Archive Extraction Layout Map
The extractor systematically slices the data stream using the following map:
1. **Global Header (8 bytes):**
   - 4 bytes: Magic Format Identifier (e.g., `FORM`)
   - 4 bytes: Total payload length (inverted Big-Endian value)
2. **First Chunk Def Block:** 8-byte padded type description tag (e.g., `TERRTITL`), followed by a 4-byte size tracker.
3. **Consecutive Assets:** 4-byte standard tag indicators (or custom `BSP ` blocks), followed by a 4-byte size tracker and the respective raw asset cluster payload.

## Usage
### Decompiling Levels (Unpacking)
1. Launch the compiled utility and click **UNPACK**.
2. Select any valid map asset archive (e.g., `ROUTE66.EXP`).
3. The tool generates a designated `level\` folder, writes individual content nodes (`.tim`, `.txt`), and maps a build layout file (`!files.cfg`).

### Compiling Levels (Packing)
1. Place your edited maps, textures, or text scripts inside the `level\` folder.
2. Ensure the structural keys inside `!files.cfg` remain uncorrupted.
3. Click **PACK** to compile the directory layout. The application outputs a reconstructed `NEW_LEVEL.EXP` ready for console emulation deployment.

## Original Credits
Developed by **DenGame** in collaboration with advanced parsing subroutines. Released under an open-source initiative to preserve legacy PlayStation 1 reverse-engineering tooling.
