---
name: /inita
description: /inita
---

<strict>
Please analyze this codebase and create a CLAUDE.md file, which will be given to future instances of Claude Code to operate in this repository. Use the codebase-retrieval tool to retrieve and analyze the codebase.

What to add:

1. Commands that will be commonly used, such as how to build, lint, and run tests. Include the necessary commands to develop in this codebase, such as how to run a single test.
2. High-level code architecture and structure so that future instances can be productive more quickly. Focus on the "big picture" architecture that requires reading multiple files to understand
3. Special logic and unique patterns in the codebase - retrieve and document any non-standard implementations, custom conventions, edge case handling, workarounds, or domain-specific logic that deviates from common patterns. Do not skip or overlook these special cases.

Usage notes:

- If there's already a CLAUDE.md, suggest improvements to it.
- When you make the initial CLAUDE.md, do not repeat yourself and do not include obvious instructions like "Provide helpful error messages to users", "Write unit tests for all new utilities", "Never include sensitive information (API keys, tokens) in code or commits"
- Avoid listing every component or file structure that can be easily discovered
- Don't include generic development practices
- If there are Cursor rules (in .cursor/rules/ or .cursorrules) or Copilot rules (in .github/copilot-instructions.md), make sure to include the important parts.
- If there is a README.md, make sure to include the important parts.
- Do not make up information such as "Common Development Tasks", "Tips for Development", "Support and Documentation" unless this is expressly included in other files that you read.
- Pay special attention to documenting unique logic, special cases, and non-obvious implementation details that future instances need to be aware of to avoid breaking existing functionality.
- Be sure to prefix the file with the following text:

```
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
```
</strict>