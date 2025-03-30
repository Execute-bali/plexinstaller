const express = require('express');
const fs = require('fs');
const path = require('path');
const app = express();
const port = process.env.PORT || 31234;

// Basic homepage with dark mode and interactive elements
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>PlexDev.live - Installation</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            :root {
                --bg-primary: #121212;
                --bg-secondary: #1e1e1e;
                --text-primary: #e4e4e4;
                --text-secondary: #a0a0a0;
                --accent: #3498db;
                --accent-dark: #2980b9;
                --success: #2ecc71;
                --warning: #f39c12;
                --danger: #e74c3c;
                --card-bg: #252525;
                --border-color: #333;
            }
            
            * {
                box-sizing: border-box;
                margin: 0;
                padding: 0;
            }
            
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                line-height: 1.6;
                color: var(--text-primary);
                background-color: var(--bg-primary);
                max-width: 900px;
                margin: 0 auto;
                padding: 20px;
                transition: all 0.3s ease;
            }
            
            h1, h2, h3 {
                color: var(--text-primary);
                margin: 1.5rem 0 1rem 0;
            }
            
            h1 {
                font-size: 2.5rem;
                border-bottom: 2px solid var(--accent);
                padding-bottom: 10px;
                margin-bottom: 1.5rem;
                position: relative;
            }
            
            h1::after {
                content: "";
                position: absolute;
                bottom: -2px;
                left: 0;
                width: 120px;
                height: 2px;
                background-color: var(--accent);
                animation: pulse 2s infinite;
            }
            
            h2 {
                font-size: 1.8rem;
                margin-top: 2rem;
            }
            
            p {
                margin: 1rem 0;
                color: var(--text-secondary);
            }
            
            .code-block {
                background-color: var(--bg-secondary);
                border: 1px solid var(--border-color);
                border-radius: 6px;
                padding: 20px;
                margin: 20px 0;
                font-family: 'Consolas', 'Courier New', monospace;
                overflow-x: auto;
                position: relative;
                box-shadow: 0 4px 8px rgba(0,0,0,0.2);
                transition: all 0.3s ease;
            }
            
            .code-block:hover {
                box-shadow: 0 8px 16px rgba(0,0,0,0.3);
                transform: translateY(-2px);
                border-color: var(--accent);
            }
            
            .code-block code {
                color: #f1c40f;
            }
            
            .code-block::before {
                content: "$ ";
                opacity: 0.5;
            }
            
            .code-block .copy-btn {
                position: absolute;
                top: 10px;
                right: 10px;
                background: var(--accent);
                color: white;
                border: none;
                border-radius: 4px;
                padding: 5px 10px;
                cursor: pointer;
                font-size: 0.8rem;
                opacity: 0;
                transition: all 0.3s ease;
            }
            
            .code-block:hover .copy-btn {
                opacity: 1;
            }
            
            .code-block .copy-btn:hover {
                background: var(--accent-dark);
            }
            
            .card {
                background-color: var(--card-bg);
                border-radius: 8px;
                padding: 20px;
                margin: 20px 0;
                box-shadow: 0 4px 8px rgba(0,0,0,0.2);
                transition: all 0.3s ease;
                border-left: 4px solid var(--accent);
            }
            
            .card:hover {
                box-shadow: 0 8px 16px rgba(0,0,0,0.3);
                transform: translateY(-2px);
            }
            
            .success {
                color: var(--success);
                font-weight: bold;
            }
            
            .warning {
                background-color: rgba(243, 156, 18, 0.1);
                border-left: 4px solid var(--warning);
                padding: 15px;
                margin: 20px 0;
                border-radius: 4px;
            }
            
            .official-note {
                background-color: rgba(52, 152, 219, 0.1);
                border-left: 4px solid var(--accent);
                padding: 15px;
                margin: 20px 0;
                border-radius: 4px;
            }
            
            .official-note a {
                color: var(--accent);
                text-decoration: none;
                font-weight: bold;
                transition: all 0.3s ease;
            }
            
            .official-note a:hover {
                color: var(--accent-dark);
                text-decoration: underline;
            }
            
            footer {
                margin-top: 40px;
                color: var(--text-secondary);
                text-align: center;
                border-top: 1px solid var(--border-color);
                padding-top: 20px;
                font-size: 0.9rem;
            }
            
            .tabs {
                display: flex;
                margin: 20px 0;
                border-bottom: 1px solid var(--border-color);
            }
            
            .tab {
                padding: 10px 20px;
                cursor: pointer;
                color: var(--text-secondary);
                transition: all 0.3s ease;
                border-bottom: 2px solid transparent;
            }
            
            .tab.active {
                color: var(--accent);
                border-bottom: 2px solid var(--accent);
            }
            
            .tab-content {
                display: none;
            }
            
            .tab-content.active {
                display: block;
                animation: fadeIn 0.5s;
            }
            
            @keyframes pulse {
                0% {
                    opacity: 0.6;
                }
                50% {
                    opacity: 1;
                }
                100% {
                    opacity: 0.6;
                }
            }
            
            @keyframes fadeIn {
                from {
                    opacity: 0;
                    transform: translateY(10px);
                }
                to {
                    opacity: 1;
                    transform: translateY(0);
                }
            }
            
            @media (max-width: 768px) {
                body {
                    padding: 15px;
                }
                
                h1 {
                    font-size: 2rem;
                }
                
                .tabs {
                    flex-direction: column;
                }
            }
        </style>
    </head>
    <body>
        <h1>PlexDev.live Installation</h1>
        <div class="official-note">
            <strong>⚠️ Important:</strong> This is an unofficial installer. The official PlexDevelopment website is 
            <a href="https://plexdevelopment.net" target="_blank">plexdevelopment.net</a>
        </div>
        
        <p>Welcome to the Unofficial PlexDevelopment Products Installer. This tool helps you easily set up various Plex products on your server.</p>
        
        <div class="tabs">
            <div class="tab active" onclick="switchTab('quick')">Quick Install</div>
            <div class="tab" onclick="switchTab('manual')">Manual Install</div>
            <div class="tab" onclick="switchTab('about')">About</div>
        </div>
        
        <div id="quick" class="tab-content active">
            <h2>Quick Installation</h2>
            <p>Run the following command in your terminal to start the installation:</p>
            
            <div class="code-block">
                <code>curl -sSL https://plexdev.live/install.sh | bash -i</code>
                <button class="copy-btn" onclick="copyToClipboard('curl -sSL https://plexdev.live/install.sh | bash -i')">Copy</button>
            </div>
        </div>
        
        <div id="manual" class="tab-content">
            <h2>Manual Installation</h2>
            <p>Alternatively, you can download the script first and then run it:</p>
            
            <div class="code-block">
                <code>curl -sSL -o install.sh https://plexdev.live/install.sh</code>
                <button class="copy-btn" onclick="copyToClipboard('curl -sSL -o install.sh https://plexdev.live/install.sh')">Copy</button>
            </div>
            
            <div class="code-block">
                <code>chmod +x install.sh</code>
                <button class="copy-btn" onclick="copyToClipboard('chmod +x install.sh')">Copy</button>
            </div>
            
            <div class="code-block">
                <code>./install.sh</code>
                <button class="copy-btn" onclick="copyToClipboard('./install.sh')">Copy</button>
            </div>
        </div>
        
        <div id="about" class="tab-content">
            <h2>About This Project</h2>
            <div class="card">
                <p>This project was created by <strong>bali0531</strong> to simplify the setup process for PlexDevelopment products.</p>
                <p>The installer automatically:</p>
                <ul style="margin-left: 20px; color: var(--text-secondary);">
                    <li>Detects your Linux distribution</li>
                    <li>Installs all necessary dependencies</li>
                    <li>Sets up Nginx configuration</li>
                    <li>Configures SSL certificates</li>
                    <li>Creates startup scripts</li>
                </ul>
            </div>
            
            <div class="warning">
                <strong>Disclaimer:</strong> This is an unofficial tool and is not officially supported by PlexDevelopment.
            </div>
        </div>
        
        <footer>
            PlexDev.live made by: bali0531 | <a href="https://plexdevelopment.net" target="_blank" style="color: var(--accent);">Official Site</a>
        </footer>
        
        <script>
            function switchTab(tabId) {
                // Hide all tab contents
                document.querySelectorAll('.tab-content').forEach(content => {
                    content.classList.remove('active');
                });
                
                // Deactivate all tabs
                document.querySelectorAll('.tab').forEach(tab => {
                    tab.classList.remove('active');
                });
                
                // Activate the selected tab and content
                document.getElementById(tabId).classList.add('active');
                
                // Find the tab button by matching its onclick attribute
                document.querySelector('.tab[onclick="switchTab(\\'' + tabId + '\\')"]').classList.add('active');
            }
            
            function copyToClipboard(text) {
                const el = document.createElement('textarea');
                el.value = text;
                document.body.appendChild(el);
                el.select();
                document.execCommand('copy');
                document.body.removeChild(el);
                
                const btn = event.target;
                const originalText = btn.textContent;
                btn.textContent = "Copied!";
                
                setTimeout(() => {
                    btn.textContent = originalText;
                }, 2000);
            }
        </script>
    </body>
    </html>
  `);
});

// Serve the install.sh script with proper headers
app.get('/install.sh', (req, res) => {
  const filePath = path.join(__dirname, 'install.sh');
  
  try {
    const data = fs.readFileSync(filePath, 'utf8');
    
    // Set appropriate headers
    res.setHeader('Content-Type', 'text/plain');
    res.setHeader('Content-Disposition', 'inline; filename="install.sh"');
    
    res.send(data);
  } catch (err) {
    console.error('Error reading installer script:', err);
    res.status(500).send('Error serving installer script');
  }
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}/`);
  console.log(`Installer script available at http://localhost:${port}/install.sh`);
});
