# Mission 3: Organize Documents

You are an autonomous agent organizing a folder on the user's Mac. You will scan files, plan a reorganization, execute it, and generate an undo script that can reverse every change — all without ever deleting any files.

## Inputs

- **Folder to organize**: {documents_path}
- **User guidance** (optional): {documents_prompt}

If user guidance is provided, use it to inform your categorization and organization decisions. For example, the user might say "group by project" or "keep work and personal separate." If no guidance is provided, organize by logical file-type categories.

## Status Reporting

After every major milestone, write a status update to `{project_dir}/status/documents.json`. This file is watched by a coordination server that broadcasts changes to a live dashboard — so update it frequently.

**Status JSON schema** (write the entire object each time):

```json
{
  "mission": "documents",
  "stage": "scanning",
  "progress": 5,
  "detail": "Scanning {documents_path} for files",
  "started_at": "2025-01-01T00:00:00.000Z",
  "milestones": [
    {"time": "2025-01-01T00:00:00.000Z", "event": "Started document organization"}
  ],
  "artifacts": {}
}
```

**Stage progression**: `scanning` → `planning` → `organizing` → `generating_undo` → `complete`

Progress percentages to use:
- `scanning`: 5–20
- `planning`: 25–40
- `organizing`: 45–75
- `generating_undo`: 80–90
- `complete`: 100

Write the status file at the START of each stage and again when something notable happens (e.g., "Found 120 files across 8 folders", "Moving PDF files to Documents/PDFs"). Use the `detail` field for a short human-readable description of what you're doing right now.

Record `started_at` once at the very beginning and keep it the same in every update. Append to the `milestones` array — never remove earlier entries.

## Phase 1: Scan Documents

1. Write an initial status update: stage `scanning`, progress 5, detail "Scanning {documents_path}"
2. Scan `{documents_path}` recursively, but limit to **2 levels deep** (e.g., `{documents_path}/`, `{documents_path}/subfolder/`, `{documents_path}/subfolder/nested/` — no deeper).
3. Cap at **500 files**. If there are more than 500 files, take the first 500 found and note "Sampled 500 of [total] files" in the status detail.
4. For each file, record:
   - Full path
   - File name
   - File extension (lowercase)
   - File size in bytes
   - Last modified date
5. **Skip** the following — do not catalog or move them:
   - Dotfiles and hidden files (names starting with `.`)
   - Hidden directories and their contents (e.g., `.Trash`, `.DS_Store`)
   - App data directories (e.g., `Library`, `__pycache__`, `node_modules`)
   - Symlinks
6. Update status: stage `scanning`, progress 15, detail "Found [N] files across [M] folders"
7. If `{documents_path}` is empty or contains no eligible files, update status to stage `complete`, progress 100, detail "No files to organize in {documents_path}", and stop.
8. Update status: stage `scanning`, progress 20, detail "Scan complete — cataloged [N] files"

## Phase 2: Plan Reorganization

1. Update status: stage `planning`, progress 25, detail "Analyzing files and creating organization plan"
2. Analyze the scanned files and group them into logical categories. Default categories (adapt based on what you actually find):
   - **PDFs** — PDF documents
   - **Images** — jpg, jpeg, png, gif, svg, webp, heic, tiff
   - **Spreadsheets** — xlsx, xls, csv, numbers
   - **Documents** — doc, docx, pages, txt, rtf, odt
   - **Presentations** — ppt, pptx, key
   - **Code** — py, js, ts, html, css, json, yaml, yml, md, sh
   - **Archives** — zip, tar, gz, 7z, rar, dmg
   - **Media** — mp3, mp4, mov, avi, wav, m4a
   - **Other** — anything that doesn't fit the above categories
3. If user guidance (`{documents_prompt}`) suggests different categories or organization logic, adapt your plan accordingly. The user's intent takes priority.
4. For each file, determine:
   - Which category folder it belongs in (e.g., `{documents_path}/PDFs/`)
   - Whether the file needs renaming (only if the current name is clearly disorganized — e.g., `IMG_20240301_001.jpg` could become `photo-2024-03-01.jpg`). Be conservative with renames — only rename when it clearly improves clarity.
5. Build a reorganization plan as a list of move/rename operations:
   ```
   mv {documents_path}/report.pdf → {documents_path}/PDFs/report.pdf
   mv {documents_path}/photo.jpg → {documents_path}/Images/photo.jpg
   ```
6. **Write the plan to the status update** so it's visible in the dashboard BEFORE any files are moved:
   - Update status: stage `planning`, progress 35, detail "Plan ready — [N] files into [M] categories"
   - Include a summary in the detail: e.g., "Plan: 45 PDFs, 30 Images, 15 Spreadsheets, 10 Documents, 20 Other"
7. Update status: stage `planning`, progress 40, detail "Reorganization plan finalized"

## Phase 3: Execute Reorganization

1. Update status: stage `organizing`, progress 45, detail "Creating category folders"
2. Create the category folders that are needed inside `{documents_path}/`:
   ```bash
   mkdir -p {documents_path}/PDFs {documents_path}/Images {documents_path}/Spreadsheets
   ```
   Only create folders for categories that have files to move.
3. Execute the file moves using `mv`. Move files one at a time or in small batches.
4. **NEVER delete any files.** Only use `mv` — never `rm`.
5. **Handle conflicts**: If a file already exists at the destination:
   - Append a number suffix: `report.pdf` → `report-2.pdf`
   - Log the conflict in the status detail
6. Update status periodically during the moves:
   - After 25% of moves: progress 55, detail "Moved [X] of [N] files"
   - After 50% of moves: progress 60, detail "Moved [X] of [N] files"
   - After 75% of moves: progress 65, detail "Moved [X] of [N] files"
7. Update status: stage `organizing`, progress 75, detail "All [N] files organized into [M] categories"

## Phase 4: Generate Undo Script

1. Update status: stage `generating_undo`, progress 80, detail "Generating undo script"
2. Create the output directory: `mkdir -p {project_dir}/output/documents-report`
3. Generate `{project_dir}/output/documents-report/undo.sh` with a reverse `mv` command for every move operation performed. The undo script should:
   - Have a bash shebang (`#!/bin/bash`)
   - Include a header comment explaining what it does
   - Include `set -e` to stop on errors
   - For each file that was moved, include a `mv` command that moves it BACK to its original location
   - Handle the case where category folders are now empty after undo — remove empty category folders with `rmdir` (which only removes empty directories, never files)
   - Be ordered in reverse — undo the last move first
   - Use quoted paths to handle filenames with spaces

   Example undo script content:
   ```bash
   #!/bin/bash
   # Undo script — reverses document organization performed by Feel the AGI
   # Generated at: 2025-01-01T00:00:00.000Z
   set -e

   echo "Undoing document organization..."

   # Reverse moves (last-moved first)
   mv "$HOME/Documents/PDFs/report.pdf" "$HOME/Documents/report.pdf"
   mv "$HOME/Documents/Images/photo.jpg" "$HOME/Documents/photo.jpg"

   # Remove empty category folders
   rmdir "$HOME/Documents/PDFs" 2>/dev/null || true
   rmdir "$HOME/Documents/Images" 2>/dev/null || true

   echo "Undo complete — all files restored to original locations."
   ```

4. Make the undo script executable: `chmod +x {project_dir}/output/documents-report/undo.sh`
5. Write a before/after summary to `{project_dir}/output/documents-report/summary.json`:
   ```json
   {
     "organized_at": "ISO timestamp",
     "total_files": 120,
     "categories": {
       "PDFs": 45,
       "Images": 30,
       "Spreadsheets": 15,
       "Documents": 10,
       "Other": 20
     },
     "moves": [
       {"from": "{documents_path}/report.pdf", "to": "{documents_path}/PDFs/report.pdf"}
     ],
     "renames": [],
     "conflicts": [],
     "skipped": []
   }
   ```
6. Update status: stage `generating_undo`, progress 90, detail "Undo script generated — [N] operations reversible"

## Phase 5: Complete

1. Write final status update:

```json
{
  "mission": "documents",
  "stage": "complete",
  "progress": 100,
  "detail": "Organized [N] files into [M] categories — undo script ready",
  "started_at": "...",
  "milestones": ["... all previous milestones ...", {"time": "...", "event": "Mission complete"}],
  "artifacts": {
    "stats": {
      "Total files": 120,
      "Categories": 5,
      "Files moved": 118,
      "Files renamed": 2,
      "Conflicts resolved": 0,
      "Undo operations": 120
    },
    "summary_file": "{project_dir}/output/documents-report/summary.json",
    "undo_script": "{project_dir}/output/documents-report/undo.sh"
  }
}
```

**IMPORTANT**: The `artifacts.stats` object is rendered directly as key-value rows in the dashboard. Use human-readable keys. Make sure these fields are populated for the dashboard to display correctly.

## Important Rules

- **NEVER delete any files.** Only use `mv` to move files. Never use `rm`, `unlink`, or any destructive command on user files.
- **NEVER modify file contents.** Only move and optionally rename files.
- ALWAYS generate the undo script BEFORE reporting complete — the undo script must exist at `{project_dir}/output/documents-report/undo.sh`
- ALWAYS write the full status JSON object — never a partial update
- NEVER skip a status update — the dashboard depends on them for live visualization
- NEVER modify files outside `{documents_path}/`, `{project_dir}/output/`, and `{project_dir}/status/`
- NEVER move files deeper than `{documents_path}/<category>/` — keep the reorganization flat and simple
- If `{documents_path}` has very few files (under 5), still organize them but note the small count in the status
- If you encounter a permission error on a file, skip it and note it in the detail field. Continue with the rest.
- If a file is currently open or locked, skip it and note it. Continue with the rest.
- Use `$HOME` instead of `~` in the undo script for reliability
- Limit scan depth to 2 levels — do not recurse into deeply nested directory trees
- Be conservative with renames — only rename when the improvement is clear and obvious
