#!/usr/bin/env node
/**
 * Claude Code Session Archive Web UI
 * A simple local web server for browsing archived sessions
 * 
 * Usage: node server.js [port]
 * Default port: 3456
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PORT = process.argv[2] || 3456;
const ARCHIVE_DIR = path.join(process.env.HOME, '.claude/session-archives');
const DB_FILE = path.join(ARCHIVE_DIR, 'sessions.db');

// Simple SQLite query helper
function queryDb(sql) {
    try {
        const result = execSync(`sqlite3 -json "${DB_FILE}" "${sql}"`, { 
            encoding: 'utf8',
            maxBuffer: 10 * 1024 * 1024 
        });
        return JSON.parse(result || '[]');
    } catch (e) {
        return [];
    }
}

// Get all sessions
function getSessions(limit = 50, offset = 0) {
    return queryDb(`
        SELECT archive_name, session_id, archived_at, working_directory,
               user_messages, assistant_messages, tool_calls, tools_used,
               preview, summary
        FROM sessions 
        ORDER BY archived_at DESC 
        LIMIT ${limit} OFFSET ${offset}
    `);
}

// Search sessions
function searchSessions(query) {
    const escaped = query.replace(/'/g, "''");
    return queryDb(`
        SELECT s.archive_name, s.archived_at, s.user_messages, s.tool_calls, s.preview, s.summary
        FROM sessions s
        WHERE s.preview LIKE '%${escaped}%' 
           OR s.summary LIKE '%${escaped}%'
        ORDER BY s.archived_at DESC
        LIMIT 30
    `);
}

// Get single session
function getSession(archiveName) {
    const sessions = queryDb(`
        SELECT * FROM sessions WHERE archive_name = '${archiveName}'
    `);
    return sessions[0] || null;
}

// Get transcript
function getTranscript(archiveName) {
    const transcriptPath = path.join(ARCHIVE_DIR, archiveName, 'transcript.jsonl');
    if (!fs.existsSync(transcriptPath)) return [];
    
    try {
        const content = fs.readFileSync(transcriptPath, 'utf8');
        return content.trim().split('\n').map(line => {
            try { return JSON.parse(line); } catch { return null; }
        }).filter(Boolean);
    } catch {
        return [];
    }
}

// Get stats
function getStats() {
    const stats = queryDb(`
        SELECT 
            COUNT(*) as total_sessions,
            SUM(user_messages) as total_user_messages,
            SUM(assistant_messages) as total_assistant_messages,
            SUM(tool_calls) as total_tool_calls
        FROM sessions
    `);
    return stats[0] || {};
}

// HTML template
const HTML_TEMPLATE = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Claude Code Session Archives</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            color: #e0e0e0;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        header {
            background: rgba(255,255,255,0.05);
            backdrop-filter: blur(10px);
            border-radius: 16px;
            padding: 24px;
            margin-bottom: 24px;
            border: 1px solid rgba(255,255,255,0.1);
        }
        h1 {
            font-size: 28px;
            background: linear-gradient(90deg, #00d4ff, #7b2ff7);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 16px;
        }
        .search-box {
            display: flex;
            gap: 12px;
        }
        .search-box input {
            flex: 1;
            padding: 12px 16px;
            border-radius: 8px;
            border: 1px solid rgba(255,255,255,0.2);
            background: rgba(255,255,255,0.05);
            color: #fff;
            font-size: 16px;
        }
        .search-box input:focus {
            outline: none;
            border-color: #00d4ff;
        }
        .search-box button {
            padding: 12px 24px;
            border-radius: 8px;
            border: none;
            background: linear-gradient(90deg, #00d4ff, #7b2ff7);
            color: #fff;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        .search-box button:hover { transform: scale(1.05); }
        .stats {
            display: flex;
            gap: 24px;
            margin-top: 16px;
        }
        .stat {
            background: rgba(255,255,255,0.05);
            padding: 12px 20px;
            border-radius: 8px;
        }
        .stat-value { font-size: 24px; font-weight: 700; color: #00d4ff; }
        .stat-label { font-size: 12px; color: #888; text-transform: uppercase; }
        .sessions { display: flex; flex-direction: column; gap: 16px; }
        .session-card {
            background: rgba(255,255,255,0.05);
            border-radius: 12px;
            padding: 20px;
            border: 1px solid rgba(255,255,255,0.1);
            cursor: pointer;
            transition: all 0.2s;
        }
        .session-card:hover {
            background: rgba(255,255,255,0.08);
            border-color: #00d4ff;
            transform: translateY(-2px);
        }
        .session-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 12px;
        }
        .session-name { font-weight: 600; color: #00d4ff; }
        .session-date { color: #888; font-size: 14px; }
        .session-preview {
            color: #aaa;
            font-size: 14px;
            line-height: 1.5;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .session-meta {
            display: flex;
            gap: 16px;
            margin-top: 12px;
            font-size: 13px;
            color: #888;
        }
        .session-meta span { display: flex; align-items: center; gap: 4px; }
        .modal {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.8);
            z-index: 1000;
            overflow-y: auto;
        }
        .modal.active { display: block; }
        .modal-content {
            background: #1a1a2e;
            max-width: 900px;
            margin: 40px auto;
            border-radius: 16px;
            border: 1px solid rgba(255,255,255,0.1);
            overflow: hidden;
        }
        .modal-header {
            padding: 20px 24px;
            background: rgba(255,255,255,0.05);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .modal-header h2 { color: #00d4ff; }
        .close-btn {
            background: none;
            border: none;
            color: #888;
            font-size: 24px;
            cursor: pointer;
        }
        .modal-body { padding: 24px; }
        .transcript {
            max-height: 500px;
            overflow-y: auto;
            background: rgba(0,0,0,0.3);
            border-radius: 8px;
            padding: 16px;
        }
        .message {
            margin-bottom: 16px;
            padding: 12px;
            border-radius: 8px;
        }
        .message.user {
            background: rgba(0,212,255,0.1);
            border-left: 3px solid #00d4ff;
        }
        .message.assistant {
            background: rgba(123,47,247,0.1);
            border-left: 3px solid #7b2ff7;
        }
        .message.tool {
            background: rgba(255,193,7,0.1);
            border-left: 3px solid #ffc107;
            font-family: monospace;
            font-size: 13px;
        }
        .message-type {
            font-size: 11px;
            text-transform: uppercase;
            color: #888;
            margin-bottom: 8px;
        }
        .summary-box {
            background: rgba(0,212,255,0.1);
            border-radius: 8px;
            padding: 16px;
            margin-bottom: 20px;
        }
        .summary-box h3 { color: #00d4ff; margin-bottom: 8px; }
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: #666;
        }
        .empty-state h2 { margin-bottom: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Claude Code Session Archives</h1>
            <div class="search-box">
                <input type="text" id="searchInput" placeholder="Search sessions..." onkeyup="if(event.key==='Enter')search()">
                <button onclick="search()">Search</button>
                <button onclick="loadSessions()" style="background: rgba(255,255,255,0.1);">All Sessions</button>
            </div>
            <div class="stats" id="stats"></div>
            <div style="margin-top: 12px; font-size: 12px; color: #666;">
                Built by the creator of <a href="https://coder1.ai" style="color: #d97706; text-decoration: none;">Coder1 IDE</a>
            </div>
        </header>
        
        <div class="sessions" id="sessions"></div>
    </div>
    
    <div class="modal" id="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h2 id="modalTitle">Session Details</h2>
                <button class="close-btn" onclick="closeModal()">&times;</button>
            </div>
            <div class="modal-body" id="modalBody"></div>
        </div>
    </div>
    
    <script>
        async function loadStats() {
            const res = await fetch('/api/stats');
            const stats = await res.json();
            document.getElementById('stats').innerHTML = \`
                <div class="stat">
                    <div class="stat-value">\${stats.total_sessions || 0}</div>
                    <div class="stat-label">Sessions</div>
                </div>
                <div class="stat">
                    <div class="stat-value">\${stats.total_user_messages || 0}</div>
                    <div class="stat-label">Messages</div>
                </div>
                <div class="stat">
                    <div class="stat-value">\${stats.total_tool_calls || 0}</div>
                    <div class="stat-label">Tool Calls</div>
                </div>
            \`;
        }
        
        async function loadSessions() {
            const res = await fetch('/api/sessions');
            const sessions = await res.json();
            renderSessions(sessions);
        }
        
        async function search() {
            const query = document.getElementById('searchInput').value;
            if (!query) return loadSessions();
            const res = await fetch('/api/search?q=' + encodeURIComponent(query));
            const sessions = await res.json();
            renderSessions(sessions);
        }
        
        function renderSessions(sessions) {
            if (!sessions.length) {
                document.getElementById('sessions').innerHTML = \`
                    <div class="empty-state">
                        <h2>No sessions found</h2>
                        <p>Sessions will appear here after you use Claude Code.</p>
                    </div>
                \`;
                return;
            }
            
            document.getElementById('sessions').innerHTML = sessions.map(s => \`
                <div class="session-card" onclick="viewSession('\${s.archive_name}')">
                    <div class="session-header">
                        <span class="session-name">\${s.archive_name}</span>
                        <span class="session-date">\${new Date(s.archived_at).toLocaleString()}</span>
                    </div>
                    <div class="session-preview">\${(s.preview || '').substring(0, 150)}...</div>
                    <div class="session-meta">
                        <span>\${s.user_messages || 0} messages</span>
                        <span>\${s.tool_calls || 0} tool calls</span>
                    </div>
                </div>
            \`).join('');
        }
        
        async function viewSession(name) {
            const [sessionRes, transcriptRes] = await Promise.all([
                fetch('/api/session/' + name),
                fetch('/api/transcript/' + name)
            ]);
            const session = await sessionRes.json();
            const transcript = await transcriptRes.json();
            
            document.getElementById('modalTitle').textContent = name;
            document.getElementById('modalBody').innerHTML = \`
                \${session.summary ? \`<div class="summary-box"><h3>AI Summary</h3><p>\${session.summary}</p></div>\` : ''}
                <div style="margin-bottom:16px;color:#888;">
                    <strong>Directory:</strong> \${session.working_directory || 'N/A'}<br>
                    <strong>Messages:</strong> \${session.user_messages} user / \${session.assistant_messages} assistant<br>
                    <strong>Tools:</strong> \${session.tools_used || 'None'}
                </div>
                <h3 style="margin-bottom:12px;">Conversation</h3>
                <div class="transcript">
                    \${transcript.map(m => {
                        const type = m.type?.includes('user') ? 'user' : m.type?.includes('assistant') ? 'assistant' : 'tool';
                        const content = m.content || m.message || (m.tool_name ? m.tool_name + ': ' + JSON.stringify(m.tool_input).substring(0,200) : '');
                        return \`<div class="message \${type}">
                            <div class="message-type">\${type}</div>
                            <div>\${(content || '').substring(0, 1000)}</div>
                        </div>\`;
                    }).join('')}
                </div>
            \`;
            document.getElementById('modal').classList.add('active');
        }
        
        function closeModal() {
            document.getElementById('modal').classList.remove('active');
        }
        
        document.getElementById('modal').onclick = (e) => {
            if (e.target.id === 'modal') closeModal();
        };
        
        loadStats();
        loadSessions();
    </script>
</body>
</html>`;

// Request handler
function handleRequest(req, res) {
    const url = new URL(req.url, `http://localhost:${PORT}`);
    const pathname = url.pathname;
    
    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Content-Type', 'application/json');
    
    try {
        if (pathname === '/' || pathname === '/index.html') {
            res.setHeader('Content-Type', 'text/html');
            res.end(HTML_TEMPLATE);
        }
        else if (pathname === '/api/sessions') {
            res.end(JSON.stringify(getSessions()));
        }
        else if (pathname === '/api/stats') {
            res.end(JSON.stringify(getStats()));
        }
        else if (pathname === '/api/search') {
            const query = url.searchParams.get('q') || '';
            res.end(JSON.stringify(searchSessions(query)));
        }
        else if (pathname.startsWith('/api/session/')) {
            const name = pathname.replace('/api/session/', '');
            const session = getSession(decodeURIComponent(name));
            res.end(JSON.stringify(session || {}));
        }
        else if (pathname.startsWith('/api/transcript/')) {
            const name = pathname.replace('/api/transcript/', '');
            const transcript = getTranscript(decodeURIComponent(name));
            res.end(JSON.stringify(transcript));
        }
        else {
            res.statusCode = 404;
            res.end(JSON.stringify({ error: 'Not found' }));
        }
    } catch (err) {
        res.statusCode = 500;
        res.end(JSON.stringify({ error: err.message }));
    }
}

// Start server
const server = http.createServer(handleRequest);
server.listen(PORT, () => {
    console.log(`
╔═══════════════════════════════════════════════════════════╗
║   Claude Code Session Archive Web UI                      ║
║                                                           ║
║   Running at: http://localhost:${PORT}                      ║
║                                                           ║
║   Press Ctrl+C to stop                                    ║
╚═══════════════════════════════════════════════════════════╝
`);
});
