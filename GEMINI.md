# GEMINI.md

## Project Overview

This project is for **Porta-Thoughty**, a voice and idea capture application for Android. The application is designed for fast, private, and intelligent capture of thoughts and ideas through voice, text, or images. It uses an AI model to process and organize these inputs into structured Markdown lists.

The architecture is **local-first**, with all data stored and processed on the device. The application is intended to be built with either **React Native** or **Flutter**.

**Core Features:**

*   One-tap voice and idea capture.
*   AI-assisted consolidation of notes into Markdown documents.
*   On-device transcription and OCR.
*   Emphasis on user privacy with local data encryption and no audio/image storage on servers.

## Building and Running

The specific commands for building, running, and testing the project are not available in the current documentation.

**TODO:** Add commands for building, running, and testing the project.

```bash
# Example commands (replace with actual commands)
# To install dependencies
npm install

# To run the application
npm run android

# To run tests
npm test
```

## Development Conventions

*   **Framework:** The project is intended to be developed using either React Native or Flutter.
*   **Database:** The application uses a local, encrypted database (SQLCipher/EncryptedFile) with the following schema:
    *   `projects(id, name, color, icon, prompt_text, created, updated)`
    *   `notes(id, project_id, text, type, image_path, ocr_original, ocr_edited, caption, include_image_pref, created, is_processed)`
    *   `docs(id, project_id, title, markdown_path, item_count, created, prompt_hash)`
    *   `settings(default_model, groq_key?, openai_key?, anthropic_key?, silence_timeout, max_note_ms)`
*   **AI Integration:** The application uses Groq Llama 3 as the default AI model, with optional support for OpenAI and Anthropic models.
*   **Testing:** The `Porta-Thoughty-PRD.txt` file outlines a test plan for MVP validation, which should be followed.
*   **Privacy:** A core principle of the application is user privacy. All data should be handled with this in mind.
