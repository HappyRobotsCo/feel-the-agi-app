#!/usr/bin/env bash
set -euo pipefail

DIR="$HOME/feel-the-agi-test-docs"
mkdir -p "$DIR"

echo "Creating test files in $DIR ..."

# PDFs
touch "$DIR/invoice_2024_jan.pdf"
touch "$DIR/invoice_2024_feb.pdf"
touch "$DIR/tax_return_2023.pdf"
touch "$DIR/rental_agreement.pdf"
touch "$DIR/health_insurance_policy.pdf"
touch "$DIR/resume_matt_2024.pdf"
touch "$DIR/quarterly_report_Q3.pdf"
touch "$DIR/board_meeting_notes.pdf"

# Images
touch "$DIR/IMG_20240315_001.jpg"
touch "$DIR/IMG_20240315_002.jpg"
touch "$DIR/screenshot_2024-01-12.png"
touch "$DIR/screenshot_2024-03-08.png"
touch "$DIR/company_logo.svg"
touch "$DIR/headshot_linkedin.jpg"
touch "$DIR/vacation_rome_2023.heic"
touch "$DIR/product_mockup_v2.png"

# Spreadsheets
touch "$DIR/budget_2024.xlsx"
touch "$DIR/client_list.csv"
touch "$DIR/expense_tracker.xlsx"
touch "$DIR/revenue_forecast_Q4.numbers"
touch "$DIR/employee_directory.csv"

# Documents
touch "$DIR/meeting_notes_jan15.docx"
touch "$DIR/project_proposal_alpha.docx"
touch "$DIR/todo_list.txt"
touch "$DIR/brainstorm_ideas.txt"
touch "$DIR/cover_letter_draft.docx"
touch "$DIR/company_handbook.pdf"
touch "$DIR/onboarding_checklist.docx"

# Presentations
touch "$DIR/pitch_deck_v3.pptx"
touch "$DIR/quarterly_review.key"
touch "$DIR/training_workshop.pptx"

# Code / config
touch "$DIR/deploy_script.sh"
touch "$DIR/config.yaml"
touch "$DIR/notes.md"
touch "$DIR/api_keys_BACKUP.json"

# Archives
touch "$DIR/old_projects_2022.zip"
touch "$DIR/website_backup.tar.gz"
touch "$DIR/fonts_collection.zip"

# Media
touch "$DIR/podcast_episode_42.mp3"
touch "$DIR/screen_recording_demo.mov"
touch "$DIR/notification_sound.wav"

# Random / misc
touch "$DIR/untitled.rtf"
touch "$DIR/scan001.pdf"
touch "$DIR/download.pdf"
touch "$DIR/copy_of_copy_final_FINAL.docx"
touch "$DIR/asdfghjkl.txt"

# A subfolder with some files
mkdir -p "$DIR/old stuff"
touch "$DIR/old stuff/contract_2021.pdf"
touch "$DIR/old stuff/taxes_2020.pdf"
touch "$DIR/old stuff/random_notes.txt"

echo ""
echo "Done! Created $(find "$DIR" -type f | wc -l | tr -d ' ') files in $DIR"
echo ""
echo "Use this path in the dashboard: ~/feel-the-agi-test-docs"
