#!/usr/bin/env python3
"""
Extract Key Points from Claude Code Session Transcript

Parses a transcript JSONL file and extracts:
- Key decisions made
- Tasks completed
- Important outcomes
- Last task in progress

Output: ~200 tokens of structured key points

Usage: extract-key-points.py <transcript_path>
"""

import json
import sys
import re
from pathlib import Path
from collections import defaultdict

# Keywords that indicate important content
DECISION_KEYWORDS = [
    'decided', 'will use', 'going with', 'chose', 'selected',
    'the plan is', 'approach:', 'solution:', 'we\'ll', "let's go with"
]

COMPLETION_KEYWORDS = [
    'completed', 'finished', 'done', 'implemented', 'fixed',
    'resolved', 'working now', 'tests pass', 'deployed'
]

OUTCOME_KEYWORDS = [
    'result:', 'outcome:', 'conclusion:', 'summary:',
    'in summary', 'to summarize', 'key takeaway'
]

IN_PROGRESS_KEYWORDS = [
    'next:', 'todo:', 'still need', 'remaining:', 'next step',
    'will need to', 'should also', 'don\'t forget'
]


def extract_content(msg: dict) -> str:
    """Extract text content from various message formats."""
    # Handle nested message structure (Claude Code format)
    if 'message' in msg and isinstance(msg['message'], dict):
        content = msg['message'].get('content', '')
        if isinstance(content, list):
            # Handle array of content blocks
            text_parts = []
            for block in content:
                if isinstance(block, dict):
                    if block.get('type') == 'text':
                        text_parts.append(block.get('text', ''))
                    elif block.get('type') == 'thinking':
                        continue  # Skip thinking blocks
                elif isinstance(block, str):
                    text_parts.append(block)
            return ' '.join(text_parts)
        return str(content) if content else ''

    # Handle direct content field
    if 'content' in msg:
        content = msg['content']
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            return ' '.join(str(c) for c in content if c)

    return ''


def get_message_type(msg: dict) -> str:
    """Determine if message is from user or assistant."""
    msg_type = msg.get('type', '')
    if msg_type in ['user', 'user_message']:
        return 'user'
    if msg_type in ['assistant', 'assistant_message']:
        return 'assistant'
    if 'message' in msg:
        role = msg['message'].get('role', '')
        if role == 'user':
            return 'user'
        if role == 'assistant':
            return 'assistant'
    return msg_type


def find_matching_content(content: str, keywords: list) -> list:
    """Find sentences containing any of the keywords."""
    matches = []
    content_lower = content.lower()

    for keyword in keywords:
        if keyword.lower() in content_lower:
            # Extract the sentence containing the keyword
            sentences = re.split(r'[.!?\n]', content)
            for sentence in sentences:
                if keyword.lower() in sentence.lower() and len(sentence.strip()) > 10:
                    clean = sentence.strip()[:150]
                    if clean not in matches:
                        matches.append(clean)

    return matches


def extract_key_points(transcript_path: str) -> dict:
    """Extract key points from transcript."""
    results = {
        'decisions': [],
        'completions': [],
        'outcomes': [],
        'in_progress': [],
        'first_user_message': '',
        'last_user_message': '',
        'message_count': {'user': 0, 'assistant': 0}
    }

    try:
        with open(transcript_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                try:
                    msg = json.loads(line)
                except json.JSONDecodeError:
                    continue

                msg_type = get_message_type(msg)
                content = extract_content(msg)

                if not content or len(content) < 10:
                    continue

                # Count messages
                if msg_type == 'user':
                    results['message_count']['user'] += 1
                    if not results['first_user_message']:
                        results['first_user_message'] = content[:200]
                    results['last_user_message'] = content[:200]
                elif msg_type == 'assistant':
                    results['message_count']['assistant'] += 1

                # Only analyze assistant messages for key points
                if msg_type != 'assistant':
                    continue

                # Find key points
                decisions = find_matching_content(content, DECISION_KEYWORDS)
                completions = find_matching_content(content, COMPLETION_KEYWORDS)
                outcomes = find_matching_content(content, OUTCOME_KEYWORDS)
                in_progress = find_matching_content(content, IN_PROGRESS_KEYWORDS)

                results['decisions'].extend(decisions)
                results['completions'].extend(completions)
                results['outcomes'].extend(outcomes)
                results['in_progress'].extend(in_progress)

    except FileNotFoundError:
        print(f"ERROR: File not found: {transcript_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    # Deduplicate and limit
    results['decisions'] = list(dict.fromkeys(results['decisions']))[:5]
    results['completions'] = list(dict.fromkeys(results['completions']))[:5]
    results['outcomes'] = list(dict.fromkeys(results['outcomes']))[:3]
    results['in_progress'] = list(dict.fromkeys(results['in_progress']))[:3]

    return results


def format_output(results: dict) -> str:
    """Format results for token-efficient output."""
    lines = []

    lines.append("## Session Key Points")
    lines.append("")

    # Message stats
    user_count = results['message_count']['user']
    asst_count = results['message_count']['assistant']
    lines.append(f"**Messages:** {user_count} user / {asst_count} assistant")
    lines.append("")

    # First request (context)
    if results['first_user_message']:
        lines.append("**Initial Request:**")
        lines.append(f"> {results['first_user_message'][:150]}...")
        lines.append("")

    # Key decisions
    if results['decisions']:
        lines.append("**Key Decisions:**")
        for d in results['decisions'][:3]:
            lines.append(f"- {d}")
        lines.append("")

    # Completions
    if results['completions']:
        lines.append("**Completed:**")
        for c in results['completions'][:3]:
            lines.append(f"- {c}")
        lines.append("")

    # In progress
    if results['in_progress']:
        lines.append("**In Progress / Next:**")
        for i in results['in_progress'][:2]:
            lines.append(f"- {i}")
        lines.append("")

    # Outcomes
    if results['outcomes']:
        lines.append("**Outcomes:**")
        for o in results['outcomes'][:2]:
            lines.append(f"- {o}")
        lines.append("")

    return '\n'.join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: extract-key-points.py <transcript_path>")
        print("Output: Structured key points (~200 tokens)")
        sys.exit(1)

    transcript_path = sys.argv[1]
    results = extract_key_points(transcript_path)
    output = format_output(results)
    print(output)


if __name__ == "__main__":
    main()
