# Mission 1: Research & Build Personal Website

You are an autonomous agent building a personal website. You have two phases: research the person, then build a polished Next.js site using what you find.

## Inputs

- **LinkedIn Profile URL**: {linkedin_url}
- **Style Preference**: {style_preference}

## Status Reporting

After every major milestone, write a status update to `{project_dir}/status/website.json`. This file is watched by a coordination server that broadcasts changes to a live dashboard — so update it frequently.

**Status JSON schema** (write the entire object each time):

```json
{
  "mission": "website",
  "stage": "researching",
  "progress": 10,
  "detail": "Searching LinkedIn profile for Jane Smith",
  "started_at": "2025-01-01T00:00:00.000Z",
  "milestones": [
    {"time": "2025-01-01T00:00:00.000Z", "event": "Started research phase"}
  ],
  "artifacts": {}
}
```

**Stage progression**: `researching` → `scaffolding` → `building` → `styling` → `serving` → `complete`

Progress percentages to use:
- `researching`: 5–20
- `scaffolding`: 25–35
- `building`: 40–65
- `styling`: 70–80
- `serving`: 85–95
- `complete`: 100

Write the status file at the START of each stage and again when something notable happens (e.g., "Found 5 years of experience", "Hero section built"). Use the `detail` field for a short human-readable description of what you're doing right now.

Record `started_at` once at the very beginning and keep it the same in every update. Append to the `milestones` array — never remove earlier entries.

## Phase 1: Research

1. Write an initial status update: stage `researching`, progress 5, detail "Starting LinkedIn research"
2. Use web search to research the person at `{linkedin_url}`
3. Extract as much as you can find:
   - Full name
   - Current job title and company
   - Professional headline/tagline
   - Past work experience (roles, companies, dates)
   - Skills and technologies
   - Education
   - Any public projects, blog posts, or writing
   - A professional summary
4. Write the structured findings to `{project_dir}/output/research/profile.json`:

```json
{
  "name": "...",
  "title": "...",
  "company": "...",
  "headline": "...",
  "experience": [
    {"role": "...", "company": "...", "dates": "...", "description": "..."}
  ],
  "skills": ["..."],
  "education": [{"school": "...", "degree": "...", "dates": "..."}],
  "projects": ["..."],
  "summary": "..."
}
```

5. Update status: stage `researching`, progress 20, detail "Research complete — found [name]'s profile"
6. If the LinkedIn profile has minimal data, work with what you have. Do not leave sections empty — generate reasonable content based on what's available.

## Phase 2: Scaffold Next.js App

1. Update status: stage `scaffolding`, progress 25, detail "Creating Next.js project"
2. Create the output directory if it doesn't exist: `mkdir -p {project_dir}/output/site`
3. Scaffold the project:
   ```bash
   cd {project_dir}/output && npx create-next-app@latest site --yes --tailwind --typescript --eslint --app --src-dir --import-alias "@/*"
   ```
   If `{project_dir}/output/site` already exists, remove it first with `rm -rf {project_dir}/output/site` before scaffolding.
4. Update status: stage `scaffolding`, progress 35, detail "Next.js project scaffolded"

## Phase 3: Build the Website

1. Update status: stage `building`, progress 40, detail "Building website content"
2. Read `{project_dir}/output/research/profile.json` to get the research data
3. Build a single-page personal website in `{project_dir}/output/site/src/app/page.tsx` with these sections:
   - **Hero**: Name, current role, professional tagline. Eye-catching and prominent.
   - **About**: A 2-3 paragraph professional summary
   - **Experience Timeline**: Work history displayed as a vertical timeline with role, company, dates, and description
   - **Skills**: Technology/skill tags displayed as a grid or tag cloud
   - **Education**: If available, displayed below experience
   - **Contact**: A simple call-to-action section (e.g., "Get in touch" with placeholder email link)
4. Write all sections in a single `page.tsx` file using Tailwind CSS for styling. Keep it as a single file — do not create separate component files.
5. Update status: stage `building`, progress 65, detail "Website content built — [number] sections created"

## Phase 4: Apply Style

1. Update status: stage `styling`, progress 70, detail "Applying {style_preference} style"
2. Apply the `{style_preference}` style theme:
   - **Minimal**: Clean white/gray palette, lots of whitespace, thin borders, sans-serif font emphasis. Subtle and elegant.
   - **Bold**: Vibrant colors, large typography, strong contrast, gradient accents. High visual impact.
   - **Corporate**: Professional blue/navy palette, structured layout, traditional business feel. Trustworthy and polished.
   - **Dark**: Dark background (#0a0a0a or #111), light text, accent color highlights, modern tech aesthetic. Sleek and developer-friendly.
3. Update `{project_dir}/output/site/src/app/globals.css` to set the appropriate color variables and base styles for the chosen theme
4. Update `{project_dir}/output/site/tailwind.config.ts` if theme colors need to be extended
5. Make sure the site is responsive — looks good on both desktop and mobile widths
6. Update status: stage `styling`, progress 80, detail "{style_preference} theme applied"

## Phase 5: Start Dev Server

1. Update status: stage `serving`, progress 85, detail "Installing dependencies"
2. Run `cd {project_dir}/output/site && npm install`
3. Start the dev server:
   ```bash
   cd {project_dir}/output/site && npm run dev -- --port 3000
   ```
   If port 3000 is busy, try 3001, then 3002. Use whichever port is available.
4. Wait a few seconds for the server to start, then verify it's running:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
   ```
5. Update status: stage `serving`, progress 95, detail "Website live at localhost:[port]"
6. Add the port to artifacts: `"artifacts": {"port": 3000, "url": "http://localhost:3000"}`

## Phase 6: Complete

1. Write final status update:

```json
{
  "mission": "website",
  "stage": "complete",
  "progress": 100,
  "detail": "Personal website for [name] is live at localhost:[port]",
  "started_at": "...",
  "milestones": ["... all previous milestones ...", {"time": "...", "event": "Mission complete"}],
  "artifacts": {
    "port": 3000,
    "url": "http://localhost:3000",
    "profile_data": "{project_dir}/output/research/profile.json",
    "site_directory": "{project_dir}/output/site"
  }
}
```

## Important Rules

- ALWAYS write the full status JSON object — never a partial update
- NEVER skip a status update — the dashboard depends on them for live visualization
- NEVER modify files outside `{project_dir}/output/` and `{project_dir}/status/`
- If you encounter an error, log it in the status `detail` field and continue if possible
- Use `--yes` flags to avoid interactive prompts (create-next-app, npm)
- The website should look professional and polished — this is a demo meant to impress
- All content should be real, derived from the LinkedIn research — no placeholder "Lorem ipsum" text
