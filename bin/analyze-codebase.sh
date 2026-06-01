#!/bin/bash
# Coder1 Memory — Codebase Analyzer
# Produces a JSON fingerprint of a project's structure, language, and framework.
# Opportunistically merges in understand-anything knowledge-graph.json if present.
#
# Usage: analyze-codebase.sh [--root <path>]
# Output: writes <project_root>/.claude/codebase-analysis.json and prints summary to stdout.

# No set -e — find/jq/grep may return non-zero on edge cases and must not abort

# ── Argument parsing ─────────────────────────────────────────────────────────
project_root="$(pwd)"
while [ $# -gt 0 ]; do
    case "$1" in
        --root)
            project_root="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Resolve to absolute path
if [ -d "$project_root" ]; then
    project_root="$(cd "$project_root" && pwd)"
else
    echo "Error: project root not found: $project_root" >&2
    exit 1
fi

project_name="$(basename "$project_root")"
analyzed_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Common exclusion args for find
EXCLUDE_ARGS=(
    -not -path '*/node_modules/*'
    -not -path '*/.git/*'
    -not -path '*/dist/*'
    -not -path '*/build/*'
    -not -path '*/.next/*'
    -not -path '*/.venv/*'
    -not -path '*/venv/*'
    -not -path '*/__pycache__/*'
    -not -path '*/target/*'
    -not -path '*/.turbo/*'
)

# ── Detect dominant language by file extension ───────────────────────────────
detect_language() {
    local best_ext=""
    local best_count=0
    for ext in ts tsx js jsx py go rs rb java cs php; do
        local count
        count=$(find "$project_root" -type f -name "*.$ext" "${EXCLUDE_ARGS[@]}" 2>/dev/null | wc -l | tr -d ' ')
        [ -z "$count" ] && count=0
        if [ "$count" -gt "$best_count" ] 2>/dev/null; then
            best_count="$count"
            best_ext="$ext"
        fi
    done
    echo "${best_ext}|${best_count}"
}

lang_result="$(detect_language)"
language="${lang_result%%|*}"
file_count="${lang_result##*|}"
[ -z "$language" ] && language="unknown"
[ -z "$file_count" ] && file_count=0

# ── Detect framework ─────────────────────────────────────────────────────────
detect_framework() {
    if [ -f "$project_root/package.json" ]; then
        for fw in next react vue svelte express fastify nuxt remix astro; do
            if jq -e ".dependencies.\"$fw\" // .devDependencies.\"$fw\"" "$project_root/package.json" >/dev/null 2>&1; then
                echo "$fw"
                return
            fi
        done
        echo "node"
        return
    fi
    if [ -f "$project_root/pyproject.toml" ]; then
        for fw in django flask fastapi; do
            if grep -qi "$fw" "$project_root/pyproject.toml" 2>/dev/null; then
                echo "$fw"
                return
            fi
        done
        echo "python"
        return
    fi
    if [ -f "$project_root/Cargo.toml" ]; then
        echo "rust"
        return
    fi
    if [ -f "$project_root/go.mod" ]; then
        echo "go"
        return
    fi
    echo "unknown"
}

framework="$(detect_framework)"

# ── Module count: directories at depth 2 under src/, lib/, or root ───────────
count_modules() {
    local base
    if [ -d "$project_root/src" ]; then
        base="$project_root/src"
    elif [ -d "$project_root/lib" ]; then
        base="$project_root/lib"
    else
        base="$project_root"
    fi
    find "$base" -mindepth 1 -maxdepth 1 -type d "${EXCLUDE_ARGS[@]}" 2>/dev/null | wc -l | tr -d ' '
}

module_count="$(count_modules)"
[ -z "$module_count" ] && module_count=0

# ── Entry points: index/main/app/server files, top 5 by path depth ───────────
entry_points_json="[]"
if [ -n "$language" ] && [ "$language" != "unknown" ]; then
    entry_points_json=$(find "$project_root" -type f \
        \( -name "index.$language" -o -name "main.$language" -o -name "app.$language" -o -name "server.$language" \) \
        "${EXCLUDE_ARGS[@]}" 2>/dev/null \
        | awk -F/ '{print NF"\t"$0}' \
        | sort -n \
        | head -5 \
        | cut -f2- \
        | sed "s|^$project_root/||" \
        | jq -R . 2>/dev/null | jq -s . 2>/dev/null || echo "[]")
    [ -z "$entry_points_json" ] && entry_points_json="[]"
fi

# ── Top directories by source file count ─────────────────────────────────────
top_dirs_json="[]"
if [ -n "$language" ] && [ "$language" != "unknown" ]; then
    top_dirs_json=$(find "$project_root" -type f -name "*.$language" "${EXCLUDE_ARGS[@]}" 2>/dev/null \
        | sed "s|^$project_root/||" \
        | awk -F/ 'NF>=3 {print $1"/"$2} NF==2 {print $1}' \
        | sort | uniq -c | sort -rn \
        | head -5 \
        | awk '{$1=""; sub(/^ +/, ""); print}' \
        | jq -R . 2>/dev/null | jq -s . 2>/dev/null || echo "[]")
    [ -z "$top_dirs_json" ] && top_dirs_json="[]"
fi

# ── understand-anything knowledge graph (optional) ───────────────────────────
ua_graph="$project_root/.understand-anything/knowledge-graph.json"
ua_present=false
ua_nodes=0
ua_layers_json="[]"
architecture_summary="null"

if [ -f "$ua_graph" ]; then
    ua_present=true
    ua_nodes=$(jq '.nodes | length' "$ua_graph" 2>/dev/null || echo 0)
    [ -z "$ua_nodes" ] && ua_nodes=0
    ua_layers_json=$(jq -c '[.layers[]?.name] // []' "$ua_graph" 2>/dev/null || echo "[]")
    [ -z "$ua_layers_json" ] && ua_layers_json="[]"
    # Build architecture summary from layer names
    layer_names=$(jq -r '.layers[]?.name' "$ua_graph" 2>/dev/null | paste -sd ' -> ' -)
    if [ -n "$layer_names" ]; then
        architecture_summary=$(jq -n --arg s "$layer_names" '$s')
    fi
fi

# ── Build final JSON via jq ──────────────────────────────────────────────────
output_dir="$project_root/.claude"
mkdir -p "$output_dir"
output_file="$output_dir/codebase-analysis.json"

jq -n \
    --arg project_root "$project_root" \
    --arg project_name "$project_name" \
    --arg analyzed_at "$analyzed_at" \
    --arg language "$language" \
    --arg framework "$framework" \
    --argjson file_count "$file_count" \
    --argjson module_count "$module_count" \
    --argjson entry_points "$entry_points_json" \
    --argjson top_directories "$top_dirs_json" \
    --argjson understand_anything_present "$ua_present" \
    --argjson understand_anything_nodes "$ua_nodes" \
    --argjson understand_anything_layers "$ua_layers_json" \
    --argjson architecture_summary "$architecture_summary" \
    '{
        project_root: $project_root,
        project_name: $project_name,
        analyzed_at: $analyzed_at,
        language: $language,
        framework: $framework,
        file_count: $file_count,
        module_count: $module_count,
        entry_points: $entry_points,
        top_directories: $top_directories,
        understand_anything_present: $understand_anything_present,
        understand_anything_nodes: $understand_anything_nodes,
        understand_anything_layers: $understand_anything_layers,
        architecture_summary: $architecture_summary
    }' > "$output_file" 2>/dev/null

# Print summary to stdout
cat "$output_file"
exit 0
