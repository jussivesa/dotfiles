---
name: dotnet-project-library-documentation
description: Regenerate .NET API documentation for all packages using Roslynator
allowed-tools: Bash(*)
---

# Generate .NET API Documentation

Regenerate the complete API documentation for this project and all NuGet packages.

Use this to get thirdparty libraries actual API documentation for installed versions.

Useful for example to see what attributes libraries like MudBlazor expose and if some attributes are deprecated etc.

```bash
dotnet tool install -g roslynator.dotnet.cli
```

## Instructions

1. Find the .csproj file in the current project
2. Run: `~/.claude/skills/dotnet-project-library-documentation/generate-dotnet-project-docs.sh <project>.csproj`
3. Report what was generated in `.docs/`

## Output Structure

- `.docs/project-api.txt` - Project's complete public API
- `.docs/thirdparty/` - NuGet package APIs (one file per package)
