# Mission 2: Email Triage

You are an autonomous agent triaging a user's Gmail inbox. You will read recent emails, categorize them, draft replies for important ones, and produce a structured summary — all without ever sending any email.

## Inputs

- **Claude's built-in Gmail MCP tools** are available as Claude Code tool calls. These are provided by the `claude.ai Gmail` connector (gmail.mcp.claude.com) and should already be authenticated. You do not need to configure anything — the tools are ready to use.

## Status Reporting

After every major milestone, write a status update to `{project_dir}/status/email.json`. This file is watched by a coordination server that broadcasts changes to a live dashboard — so update it frequently.

**Status JSON schema** (write the entire object each time):

```json
{
  "mission": "email",
  "stage": "connecting",
  "progress": 5,
  "detail": "Connecting to Gmail via MCP",
  "started_at": "2025-01-01T00:00:00.000Z",
  "milestones": [
    {"time": "2025-01-01T00:00:00.000Z", "event": "Started email triage"}
  ],
  "artifacts": {}
}
```

**Stage progression**: `connecting` → `reading` → `categorizing` → `drafting` → `complete`

Progress percentages to use:
- `connecting`: 5–10
- `reading`: 15–40
- `categorizing`: 45–65
- `drafting`: 70–90
- `complete`: 100

Write the status file at the START of each stage and again when something notable happens (e.g., "Found 32 emails from last 7 days", "3 urgent emails identified"). Use the `detail` field for a short human-readable description of what you're doing right now.

Record `started_at` once at the very beginning and keep it the same in every update. Append to the `milestones` array — never remove earlier entries.

## Phase 1: Connect to Gmail

1. Write an initial status update: stage `connecting`, progress 5, detail "Connecting to Gmail"
2. The built-in `claude.ai Gmail` MCP server should already be authenticated. Verify access by searching for a recent email. Use whatever Gmail search/list tool is available to fetch 1 recent email from the last 7 days.
3. If the connection succeeds, update status: stage `connecting`, progress 10, detail "Gmail connected successfully"
4. If the connection fails (e.g., the Gmail MCP server is not authenticated), update status with the error in `detail` and set stage to `complete`, progress 100, detail "Could not connect to Gmail — please authenticate via claude.ai/settings/connectors", and stop.

## Phase 2: Read Emails

1. Update status: stage `reading`, progress 15, detail "Fetching emails from last 7 days"
2. Use the Gmail MCP search tool to fetch up to 50 recent emails from the last 7 days. Use Gmail query syntax like `newer_than:7d` with a max of 50 results.
3. Update status: stage `reading`, progress 20, detail "Found [N] emails — reading contents"
4. For each email, use the Gmail MCP read/get tool to read the full message content. Process them in batches if needed. Extract for each email:
   - Subject
   - Sender (name and email)
   - Date received
   - Body text (first 500 characters is sufficient for categorization)
   - Whether it has attachments
   - Thread ID for context
5. Update status periodically as you read through emails:
   - After 25%: progress 25, detail "Read [X] of [N] emails"
   - After 50%: progress 30, detail "Read [X] of [N] emails"
   - After 75%: progress 35, detail "Read [X] of [N] emails"
6. Update status: stage `reading`, progress 40, detail "All [N] emails read"

## Phase 3: Categorize

1. Update status: stage `categorizing`, progress 45, detail "Categorizing emails"
2. Assign each email one of these categories:
   - **urgent**: Time-sensitive, requires immediate attention (e.g., meeting in 24h, deadline, action required, account security alerts)
   - **needs_reply**: Not urgent but expects a response (questions, requests, invitations)
   - **newsletter**: Marketing emails, digests, mailing lists, automated content
   - **informational**: FYI messages, receipts, confirmations, shipping updates — no reply needed
   - **noise**: Spam-like, promotions, social media notifications, automated notifications with no value
3. Build a categorized data structure:
   ```json
   {
     "urgent": [{"id": "...", "subject": "...", "from": "...", "date": "...", "summary": "2-3 sentence summary", "has_attachments": false}],
     "needs_reply": [{"id": "...", "subject": "...", "from": "...", "date": "...", "summary": "2-3 sentence summary", "has_attachments": false}],
     "newsletter": [{"id": "...", "subject": "...", "from": "...", "one_liner": "One-line summary"}],
     "informational": [{"id": "...", "subject": "...", "from": "...", "one_liner": "One-line summary"}],
     "noise": []
   }
   ```
4. For **urgent** and **needs_reply** emails: write a 2-3 sentence summary capturing the key information and what action is needed
5. For **newsletter** and **informational** emails: write a one-line summary
6. For **noise** emails: just keep count — no individual entries needed (store as empty array, count separately)
7. Update status: stage `categorizing`, progress 65, detail "Categorized [N] emails — [X] urgent, [Y] need reply"

## Phase 4: Draft Replies

1. Update status: stage `drafting`, progress 70, detail "Drafting replies for urgent and needs_reply emails"
2. For each **urgent** email: write a concise, professional draft reply (2-4 sentences). The reply should:
   - Acknowledge the urgency
   - Provide a reasonable response or ask a clarifying question
   - Be ready to send with minimal editing
3. For each **needs_reply** email: write a helpful draft reply (2-4 sentences). The reply should:
   - Address the question or request
   - Be polite and professional
   - Include relevant context from the original email
4. Store the draft reply in each email's entry as a `draft` field
5. Update status periodically: progress 75-85, detail "Drafted [X] of [Y] replies"
6. Write the complete triage results to `{project_dir}/output/email-summary/triage.json`:
   ```json
   {
     "triaged_at": "ISO timestamp",
     "total_emails": 50,
     "period": "last 7 days",
     "categories": {
       "urgent": [...],
       "needs_reply": [...],
       "newsletter": [...],
       "informational": [...],
       "noise_count": 5
     },
     "summary": {
       "total": 50,
       "urgent": 3,
       "needs_reply": 8,
       "newsletter": 15,
       "informational": 12,
       "noise": 12
     }
   }
   ```
7. Make sure to create the output directory first: `mkdir -p {project_dir}/output/email-summary`
8. Update status: stage `drafting`, progress 90, detail "All drafts written — [X] replies prepared"

## Phase 5: Complete

1. Write final status update:

```json
{
  "mission": "email",
  "stage": "complete",
  "progress": 100,
  "detail": "Triaged [N] emails — [X] urgent, [Y] need reply, [Z] drafts written",
  "started_at": "...",
  "milestones": ["... all previous milestones ...", {"time": "...", "event": "Mission complete"}],
  "artifacts": {
    "stats": {
      "Total emails": 50,
      "Urgent": 3,
      "Needs reply": 8,
      "Newsletter": 15,
      "Informational": 12,
      "Noise": 12,
      "Drafts written": 11
    },
    "urgent": [
      {
        "subject": "Meeting tomorrow at 9am",
        "summary": "John wants to confirm your attendance at the quarterly planning meeting tomorrow morning.",
        "draft": "Hi John, thanks for the reminder. I'll be there at 9am. Looking forward to it."
      }
    ],
    "triage_file": "{project_dir}/output/email-summary/triage.json"
  }
}
```

**IMPORTANT**: The `artifacts.stats` object is rendered directly as key-value rows in the dashboard. Use human-readable keys. The `artifacts.urgent` array is rendered as expandable items showing subject, summary, and draft reply. Make sure these fields are populated for the dashboard to display correctly.

## Important Rules

- **NEVER send any email.** NEVER use any tool that sends, forwards, or replies to email. You are READ-ONLY.
- NEVER create drafts in Gmail via MCP tools — only write draft text locally in the triage JSON
- ALWAYS write the full status JSON object — never a partial update
- NEVER skip a status update — the dashboard depends on them for live visualization
- NEVER modify files outside `{project_dir}/output/` and `{project_dir}/status/`
- If an email is in a language you don't fully understand, still categorize it based on available context and note the language
- If there are fewer than 50 emails in the last 7 days, process all of them and note the actual count
- If there are zero emails, set stage to `complete` with detail "No emails found in the last 7 days" and empty categories
- Treat email content as sensitive — do not log full email bodies to status. Use summaries only.
- If you encounter an error reading a specific email, skip it and note it in the detail field. Continue with the rest.
