#!/bin/bash

# Generate comprehensive API documentation for .NET projects using Roslynator
# Author: Martin Alderson (https://martinalderson.com)
# License: MIT License - provided "as is" without warranty of any kind
# Usage: ./generate-docs.sh [project.csproj]

set -euo pipefail

# Configuration
PROJECT=${1:-ConsoleApp.csproj}
DOCS_DIR=".docs"
THIRDPARTY_DIR="$DOCS_DIR/thirdparty"

# Get target framework from project file
get_target_framework() {
    local project_file="$1"
    grep -o '<TargetFramework>[^<]*</TargetFramework>' "$project_file" | \
        sed 's/<[^>]*>//g' | head -1
}

# Find best matching DLL for a package, preferring project's target framework
find_best_dll() {
    local lib_path="$1"
    local package_name="$2"
    local target_framework="$3"

    # Build framework priority list: project's target first, then fallbacks
    local frameworks=()
    if [[ -n "$target_framework" ]]; then
        frameworks+=("$target_framework")
    fi
    # Add remaining frameworks in priority order (skip if already added)
    for fw in net10.0 net9.0 net8.0 net7.0 net6.0 netstandard2.1 netstandard2.0; do
        [[ "$fw" != "$target_framework" ]] && frameworks+=("$fw")
    done

    for framework in "${frameworks[@]}"; do
        local framework_path="$lib_path/$framework"
        [[ -d "$framework_path" ]] || continue

        # First try exact package name match
        local dll_path="$framework_path/$package_name.dll"
        if [[ -f "$dll_path" ]]; then
            echo "$dll_path"
            return 0
        fi

        # Try finding any DLL in this framework folder (handles mismatched names)
        local found=$(find "$framework_path" -maxdepth 1 -name "*.dll" 2>/dev/null | head -1)
        if [[ -n "$found" ]]; then
            echo "$found"
            return 0
        fi
    done

    # Fallback: find any net* DLL (prefer net over netstandard)
    local found=$(find "$lib_path" -path "*/net[0-9]*/*.dll" 2>/dev/null | sort -rV | head -1)
    if [[ -n "$found" ]]; then
        echo "$found"
        return 0
    fi

    # Last resort: any DLL in lib folder
    find "$lib_path" -name "*.dll" 2>/dev/null | head -1
}

# Get NuGet packages referenced in project
get_project_dlls() {
    local project_file="$1"
    local target_framework=$(get_target_framework "$project_file")

    # Extract PackageReference names and versions from csproj
    grep -o 'PackageReference Include="[^"]*" Version="[^"]*"' "$project_file" | \
    while read -r line; do
        local package_name=$(echo "$line" | sed -n 's/.*Include="\([^"]*\)".*/\1/p')
        local version=$(echo "$line" | sed -n 's/.*Version="\([^"]*\)".*/\1/p')

        # Convert package name to lowercase for NuGet folder structure
        local package_folder=$(echo "$package_name" | tr '[:upper:]' '[:lower:]')
        local lib_path="$HOME/.nuget/packages/$package_folder/$version/lib"

        # Find best matching DLL
        if [[ -d "$lib_path" ]]; then
            find_best_dll "$lib_path" "$package_name" "$target_framework"
        fi
    done
}

# Generate API documentation for a DLL (filtering out project symbols)
document_dll() {
    local dll_path="$1"
    local output_file="$2"
    local project_name=$(basename "$PROJECT" .csproj)

    # Use --group-by-assembly to separate external and project symbols cleanly
    # Skip project assembly section, only output external assembly symbols
    roslynator list-symbols "$PROJECT" \
        --external-assemblies "$dll_path" \
        --visibility public \
        --depth member \
        --group-by-assembly 2>/dev/null | \
        awk -v proj_asm="^assembly $project_name," '
            /^assembly / { in_project = ($0 ~ proj_asm) }
            !in_project { print }
        ' > "$output_file"
}

main() {
    echo "🔍 Generating documentation for $PROJECT..."

    # Detect target framework
    local target_framework=$(get_target_framework "$PROJECT")
    echo "🎯 Target framework: ${target_framework:-unknown}"

    # Clean and create structure
    rm -rf "$DOCS_DIR"
    mkdir -p "$THIRDPARTY_DIR"

    # Generate project documentation
    echo "📚 Generating project API documentation..."
    roslynator list-symbols "$PROJECT" \
        --visibility public \
        --depth member \
        > "$DOCS_DIR/project-api.txt"
    
    # Find and document NuGet packages from project references
    echo "📖 Documenting third-party libraries..."
    
    # Get the list of DLLs and process them
    local dll_list=$(get_project_dlls "$PROJECT")
    local documented_count=0
    
    for dll_path in $dll_list; do
        [[ -z "$dll_path" ]] && continue
        if [[ -f "$dll_path" ]]; then
            local package_name=$(basename "$dll_path" .dll)
            local output_file="$THIRDPARTY_DIR/${package_name}-api.txt"
            
            echo "  📦 $package_name..."
            
            if document_dll "$dll_path" "$output_file"; then
                local line_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
                echo "    ✅ $line_count lines"
                documented_count=$((documented_count + 1))
            else
                echo "    ⚠️  Failed"
            fi
        fi
    done
    
    # Generate summary
    cat > "$DOCS_DIR/README.md" << EOF
# API Documentation

## Project API
- \`project-api.txt\` - All project classes and methods

## Third-party Libraries ($documented_count documented)
$(if [[ $documented_count -gt 0 ]]; then
    ls "$THIRDPARTY_DIR" | sed 's/-api\.txt$//' | sed 's/^/- /'
else
    echo "- None found"
fi)

## Usage
\`\`\`bash
# Search project APIs
grep "MethodName" docs/project-api.txt

# Search third-party APIs  
grep -r "MethodName" docs/thirdparty/

# List all third-party packages
ls docs/thirdparty/
\`\`\`
EOF

    echo "✅ Documentation complete!"
    echo "   📄 Project: $(wc -l < "$DOCS_DIR/project-api.txt") lines"
    echo "   📦 Libraries: $documented_count packages"
    echo "   📁 Output: $DOCS_DIR/"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
