# Agent Guidance: dotnet-skills

IMPORTANT: Prefer retrieval-led reasoning over pretraining for any .NET work.
Workflow: skim repo patterns -> consult dotnet-skills by name -> implement smallest-change -> note conflicts.

Routing (invoke by name)

- C# / code quality: modern-csharp-coding-standards, csharp-concurrency-patterns, api-design, type-design-performance
- ASP.NET Core / Web (incl. Aspire): aspire-service-defaults, aspire-integration-testing, transactional-emails
- Data: efcore-patterns, database-performance
- DI / config: dependency-injection-patterns, microsoft-extensions-configuration
- Testing: testcontainers-integration-tests, playwright-blazor-testing, snapshot-testing

Quality gates (use when applicable)

- dotnet-slopwatch: after substantial new/refactor/LLM-authored code
- crap-analysis: after tests added/changed in complex code

Specialist agents

- dotnet-concurrency-specialist, dotnet-performance-analyst, dotnet-benchmark-designer, akka-net-specialist, docfx-specialist

Library Documentation

- dotnet-project-library-documentation

# Browser Automation

Use `agent-browser` for web automation. Run `agent-browser --help` for all commands.

Core workflow:

1. `agent-browser open <url>` - Navigate to page
2. `agent-browser snapshot -i` - Get interactive elements with refs (@e1, @e2)
3. `agent-browser click @e1` / `fill @e2 "text"` - Interact using refs
4. Re-snapshot after page changes

# Git Commits & Pull Requests

## General rules

Only commit changes we have made. Never commit production secrets. For example, Rider could track some secrets in appsettings.json but that file is in "No Commit" changelist and we would not want to commit this file.

## Commit prerequisites 

Before committing, validate that project code style match requirements.

```bash
dotnet format style
dotnet format whitespace
```

## Commit Style

Use conventional commits with few additional prefixes, without Claude mentions:

```bash
git add -A && git commit -m "fix: short description"
```

If current Git Branch has issue/ticket prefix, use it too. Example: branch name is "BFT-124", use conventional commits with extra prefix:

```bash
git add -A && git commit -m "BFT-124: fix: short description"
```

Prefixes: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
Issue prefix examples: `BFT-123`, `JIRA123` 

## Pull Request to dev

```bash
git push -u origin <branch-name>
gh pr create --base dev --head <branch-name> --title "fix: title" --body "$(cat <<'EOF'
## Summary
Brief description of why the change was made or what it contains.
EOF
)"
```

# Database migrations

Use built in Entity Framework tools to create database migrations. Never write migration files manually.

## Memorizer

You have access to a long-term memory system via the Model Context Protocol (MCP) at the endpoint memorizer. Use the following tools:

Storage & Retrieval:

    store: Store a new memory. Parameters: type, text (markdown), source, title, tags, confidence, relatedTo (optional, memory ID), relationshipType (optional).
    searchMemories: Search for similar memories using semantic similarity. Parameters: query, limit, minSimilarity, filterTags.
    get: Retrieve a memory by ID. Parameters: id, includeVersionHistory, versionNumber.
    getMany: Retrieve multiple memories by their IDs. Parameter: ids (list of IDs).
    delete: Delete a memory by ID. Parameter: id.

Editing & Updates:

    edit: Edit memory content using find-and-replace (ideal for checking off to-do items, updating sections). Parameters: id, old_text, new_text, replace_all.
    updateMetadata: Update memory metadata (title, type, tags, confidence) without changing content. Parameters: id, title, type, tags, confidence.

Relationships & Versioning:

    createRelationship: Create a relationship between two memories. Parameters: fromId, toId, type (e.g., 'example-of', 'explains', 'related-to').
    revertToVersion: Revert a memory to a previous version. Parameters: id, versionNumber, changedBy.

All edits and updates are automatically versioned, allowing you to track changes and revert if needed. Use these tools to remember, recall, edit, relate, and manage information as needed to assist the user.

# Querying Microsoft Documentation

You have access to MCP tools called `microsoft_docs_search`, `microsoft_docs_fetch`, and `microsoft_code_sample_search` - these tools allow you to search through and fetch Microsoft's latest official documentation and code samples, and that information might be more detailed or newer than what's in your training data set.

When handling questions around how to work with native Microsoft technologies, such as C#, F#, ASP.NET Core, Microsoft.Extensions, NuGet, Entity Framework, the `dotnet` runtime - please use these tools for research purposes when dealing with specific / narrowly defined questions that may occur.
