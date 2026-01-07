# Chrome DevTools MCP Skill

A comprehensive skill for controlling and inspecting Chrome browser using the Chrome DevTools Protocol through the `chrome-devtools-mcp` npm package.

## Overview

This skill provides complete browser automation and debugging capabilities through Chrome DevTools, enabling:
- Page navigation and tab management
- Element interaction (clicks, typing, forms)
- Console and network debugging
- Performance analysis and tracing
- Device and network emulation
- Screenshots and DOM snapshots

## Installation

Ensure the `chrome-devtools-mcp` package is configured in your Claude Code MCP settings:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest"]
    }
  }
}
```

### Optional Configuration

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "chrome-devtools-mcp@latest",
        "--headless=false",
        "--categoryEmulation",
        "--categoryPerformance",
        "--categoryNetwork"
      ]
    }
  }
}
```

**Configuration flags:**
- `--headless=false` - Show browser window (default: true)
- `--categoryEmulation` - Enable device/network emulation tools
- `--categoryPerformance` - Enable performance tracing tools
- `--categoryNetwork` - Enable network debugging tools
- `--channel=stable|beta|dev|canary` - Chrome channel to use
- `--isolated` - Use isolated browser profile

## Skill Structure

```
chrome-devtools/
├── SKILL.md                      # Main skill definition
├── README.md                     # This file
└── references/
    ├── NAVIGATION.md             # Page navigation and tab management
    ├── INTERACTION.md            # Element interaction (clicks, forms, etc.)
    ├── DEBUGGING.md              # Console logs and network debugging
    ├── PERFORMANCE.md            # Performance tracing and analysis
    ├── EMULATION.md              # Device and network emulation
    └── VISUAL.md                 # Screenshots and DOM snapshots
```

## Tool Categories

### Navigation (6 tools)
- `navigate_page` - Go to URLs
- `new_page` - Create new tabs
- `close_page` - Close tabs
- `list_pages` - View open tabs
- `select_page` - Switch tabs
- `wait_for` - Wait for conditions

### Interaction (8 tools)
- `click` - Click elements
- `fill` - Enter text
- `fill_form` - Fill multiple fields
- `press_key` - Keyboard input
- `hover` - Hover over elements
- `drag` - Drag and drop
- `upload_file` - Upload files
- `handle_dialog` - Manage alerts/dialogs

### Debugging (5 tools)
- `list_console_messages` - View console logs
- `get_console_message` - Get specific log
- `list_network_requests` - View network requests
- `get_network_request` - Get request details
- `evaluate_script` - Execute JavaScript

### Performance (3 tools)
- `performance_start_trace` - Begin recording
- `performance_stop_trace` - End recording
- `performance_analyze_insight` - Get recommendations

### Emulation (2 tools)
- `emulate` - Device/network simulation
- `resize_page` - Viewport sizing

### Visual (2 tools)
- `take_screenshot` - Capture screenshots
- `take_snapshot` - Capture DOM state

## Usage Examples

### Take a Screenshot
```
User: "Take a screenshot of example.com"

Agent workflow:
1. Reads references/NAVIGATION.md and references/VISUAL.md
2. Uses navigate_page to go to example.com
3. Uses wait_for to ensure page is loaded
4. Uses take_screenshot to capture the page
```

### Debug Network Issues
```
User: "Check why the API call is failing on /dashboard"

Agent workflow:
1. Reads references/NAVIGATION.md and references/DEBUGGING.md
2. Uses navigate_page to go to /dashboard
3. Uses wait_for to ensure page loads
4. Uses list_network_requests to see all requests
5. Uses get_network_request to inspect failed request
6. Reports findings with error details
```

### Test Mobile Layout
```
User: "How does the site look on iPhone 13?"

Agent workflow:
1. Reads references/EMULATION.md, references/NAVIGATION.md, and references/VISUAL.md
2. Uses emulate to set iPhone 13 device
3. Uses navigate_page to load the site
4. Uses wait_for to ensure content loads
5. Uses take_screenshot to capture mobile view
```

### Analyze Performance
```
User: "Check the performance of our homepage"

Agent workflow:
1. Reads references/PERFORMANCE.md
2. Uses performance_start_trace with the URL
3. Uses wait_for to ensure page loads
4. Uses performance_stop_trace to end recording
5. Uses performance_analyze_insight to get recommendations
6. Reports Core Web Vitals and optimization suggestions
```

### Fill and Submit Form
```
User: "Fill out the contact form on example.com/contact"

Agent workflow:
1. Reads references/NAVIGATION.md and references/INTERACTION.md
2. Uses navigate_page to go to /contact
3. Uses wait_for to ensure form loads
4. Uses fill_form to populate all fields
5. Uses click to submit the form
6. Uses take_screenshot to verify submission
```

## Reference Loading

**CRITICAL**: The skill requires loading appropriate reference files before using any tools. The SKILL.md file contains mandatory instructions to load references using the Read tool before executing operations.

Each reference file contains:
- Detailed tool parameters and examples
- Common workflows and patterns
- Best practices
- Troubleshooting guides

## Common Workflows

### Web Testing
```
navigate → wait → interact → verify → screenshot
```

### Performance Analysis
```
start_trace → navigate → wait → stop_trace → analyze
```

### Debugging
```
navigate → check_console → check_network → execute_diagnostics
```

### Responsive Design Testing
```
for each device:
  emulate → navigate → wait → screenshot → compare
```

## Best Practices

1. **Always wait after navigation** - Use `wait_for` to ensure readiness
2. **Use specific selectors** - Avoid ambiguous element selectors
3. **Handle errors gracefully** - Check console and network for issues
4. **Take screenshots** - Visual confirmation is valuable
5. **Chain operations logically** - Navigate → interact → verify
6. **Clean up resources** - Close pages when done
7. **Test multiple conditions** - Different devices, networks, states
8. **Load references first** - Always read relevant reference files

## Related Skills

- **github** - Manage GitHub issues (can create issues from test failures)
- **review** - Code review (can review test automation code)

## Resources

- [Chrome DevTools MCP GitHub](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- [Chrome DevTools MCP npm](https://www.npmjs.com/package/chrome-devtools-mcp)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [Chrome for Developers Blog](https://developer.chrome.com/blog/chrome-devtools-mcp)

## Troubleshooting

**MCP server not connecting:**
- Verify `chrome-devtools-mcp` is in your MCP config
- Check if Chrome is installed
- Try running `npx chrome-devtools-mcp@latest --help`

**Browser not opening:**
- Check `--headless` flag setting
- Verify Chrome executable path
- Check for permission issues

**Tools not working:**
- Ensure correct category flags are enabled
- Check MCP server logs
- Verify tool names match MCP definitions

**Performance issues:**
- Close unused tabs with `close_page`
- Use headless mode for faster execution
- Limit trace duration for performance tests

## Version

Skill created for `chrome-devtools-mcp@latest` (as of January 2025)

For the latest features and updates, check the [npm package page](https://www.npmjs.com/package/chrome-devtools-mcp).
