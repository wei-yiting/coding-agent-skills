---
name: render-mermaid-in-session
description: >-
  Render Mermaid diagrams as PNG images and open them in macOS Preview. MUST use whenever
  showing any Mermaid diagram in conversation (architecture, flowchart, sequence, ER, state,
  class diagrams, etc.) — never output raw ```mermaid code blocks in chat; always render to an
  image instead.
---

# Render Mermaid Diagram

This skill renders Mermaid diagram definitions into PNG images and opens them in macOS Preview for the user to view.

## Why this exists

Raw Mermaid code blocks in chat are not rendered visually — the user sees syntax, not a diagram. Every Mermaid diagram must be rendered to an image so the user actually sees what you're communicating.

## Steps

1. **Create a temp directory** to avoid polluting the project:
   ```
   tmpdir=$(mktemp -d)
   ```

2. **Write the `.mmd` file** with a descriptive topic-based name (e.g., `auth_flow.mmd`, `data_pipeline.mmd`, `system_overview.mmd`). Never use generic names like `diagram.mmd` or `out.mmd`:
   ```
   Write file to $tmpdir/<topic>.mmd
   ```

3. **Render to PNG** using mmdc via nvm:
   ```
   . $NVM_DIR/nvm.sh && mmdc -i $tmpdir/<topic>.mmd -o $tmpdir/<topic>.png -s 3 -w 1600 -b white
   ```

4. **Open in Preview**:
   ```
   open $tmpdir/<topic>.png
   ```

## File naming

The file name must reflect the diagram's topic — it helps the user identify the file in Preview if multiple diagrams are open:

- `sec_pipeline_scope.png` — good
- `er_diagram_filings.png` — good
- `out.png` — bad
- `diagram.png` — bad

## Important

- All four steps should execute in sequence within a single workflow — do not stop between steps
- If `mmdc` fails, check the Mermaid syntax and retry with corrected syntax
- If the user asks you to revise a diagram, re-render and re-open — do not paste corrected Mermaid code in chat
