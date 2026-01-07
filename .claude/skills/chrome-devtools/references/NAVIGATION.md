# Chrome DevTools Navigation Reference

Control browser navigation, manage tabs, and handle page lifecycle events.

## Available Tools

### navigate_page
Navigate the browser to a specific URL.

**Parameters:**
- `url` (required): The URL to navigate to
- `pageId` (optional): Specific page/tab ID to navigate

**Example:**
```
Navigate to homepage:
mcp__chrome-devtools__navigate_page
  url: https://example.com

Navigate specific tab:
mcp__chrome-devtools__navigate_page
  url: https://example.com/login
  pageId: page-123
```

**Common use cases:**
- Opening websites for testing
- Navigating to specific app routes
- Refreshing pages (navigate to current URL)

---

### new_page
Create a new browser tab.

**Parameters:**
- `url` (optional): URL to open in the new tab

**Example:**
```
Create blank tab:
mcp__chrome-devtools__new_page

Create tab with URL:
mcp__chrome-devtools__new_page
  url: https://example.com
```

**Common use cases:**
- Opening multiple pages for comparison
- Isolating test scenarios
- Parallel page operations

---

### close_page
Close a browser tab.

**Parameters:**
- `pageId` (required): The ID of the page/tab to close

**Example:**
```
Close specific tab:
mcp__chrome-devtools__close_page
  pageId: page-123
```

**Common use cases:**
- Cleaning up after tests
- Managing browser resources
- Closing completed workflows

---

### list_pages
List all open browser tabs/pages.

**Parameters:** None

**Example:**
```
Get all open pages:
mcp__chrome-devtools__list_pages
```

**Returns:**
Array of page objects with:
- `pageId`: Unique identifier
- `url`: Current URL
- `title`: Page title

**Common use cases:**
- Finding specific tabs
- Checking what's open
- Getting page IDs for other operations

---

### select_page
Switch focus to a specific tab.

**Parameters:**
- `pageId` (required): The ID of the page/tab to select

**Example:**
```
Switch to specific tab:
mcp__chrome-devtools__select_page
  pageId: page-123
```

**Common use cases:**
- Switching between test scenarios
- Focusing on specific page for operations
- Multi-tab workflows

---

### wait_for
Wait for specific conditions before proceeding.

**Parameters:**
- `condition` (required): What to wait for (e.g., "networkidle", "load", selector)
- `timeout` (optional): Max wait time in milliseconds
- `pageId` (optional): Specific page to wait on

**Example:**
```
Wait for page load:
mcp__chrome-devtools__wait_for
  condition: load

Wait for network idle:
mcp__chrome-devtools__wait_for
  condition: networkidle

Wait for element:
mcp__chrome-devtools__wait_for
  condition: "#login-button"
  timeout: 5000

Wait for specific page:
mcp__chrome-devtools__wait_for
  condition: load
  pageId: page-123
```

**Condition types:**
- `load` - Wait for page load event
- `networkidle` - Wait until network is idle
- `domcontentloaded` - Wait for DOM ready
- CSS selector - Wait for element to appear

**Common use cases:**
- Ensuring page readiness before interaction
- Waiting for dynamic content
- Synchronizing test steps
- Handling slow-loading pages

---

## Navigation Workflows

### Basic Page Navigation
```
1. Navigate to URL:
   mcp__chrome-devtools__navigate_page
     url: https://example.com

2. Wait for page ready:
   mcp__chrome-devtools__wait_for
     condition: networkidle

3. Proceed with operations...
```

### Multi-Tab Workflow
```
1. List current tabs:
   mcp__chrome-devtools__list_pages

2. Create new tab:
   mcp__chrome-devtools__new_page
     url: https://example.com/page2

3. Switch between tabs:
   mcp__chrome-devtools__select_page
     pageId: page-123

4. Close when done:
   mcp__chrome-devtools__close_page
     pageId: page-123
```

### Progressive Web App Navigation
```
1. Navigate to app:
   mcp__chrome-devtools__navigate_page
     url: https://app.example.com

2. Wait for app shell:
   mcp__chrome-devtools__wait_for
     condition: "#app-root"

3. Wait for data load:
   mcp__chrome-devtools__wait_for
     condition: networkidle

4. Proceed with testing...
```

### Handling Slow Pages
```
1. Navigate with explicit wait:
   mcp__chrome-devtools__navigate_page
     url: https://slow-site.example.com

2. Wait with timeout:
   mcp__chrome-devtools__wait_for
     condition: load
     timeout: 30000

3. Verify loaded:
   mcp__chrome-devtools__list_console_messages
   (check for errors)
```

---

## Best Practices

1. **Always wait after navigation** - Use `wait_for` to ensure page readiness
2. **Use networkidle for SPAs** - Single-page apps need network idle, not just load
3. **Handle timeouts gracefully** - Set appropriate timeout values
4. **Clean up tabs** - Close pages when done to free resources
5. **Check console after navigation** - Verify no critical errors
6. **Use specific selectors for waiting** - Wait for actual content, not just load event

---

## Common Patterns

### Safe Navigation Pattern
```
navigate_page → wait_for(networkidle) → verify success
```

### Tab Management Pattern
```
list_pages → identify target → select_page → operate → close_page
```

### Refresh Pattern
```
Get current URL → navigate_page(same URL) → wait_for
```

### Multi-Step Navigation Pattern
```
navigate_page(URL1) → wait_for → interact →
navigate_page(URL2) → wait_for → verify
```

---

## Troubleshooting

**Page won't load:**
- Increase timeout in `wait_for`
- Check network connectivity
- Verify URL is accessible
- Check console for errors

**Wait times out:**
- Use more specific wait conditions
- Check if element selector is correct
- Try `networkidle` instead of specific selector
- Verify page actually loads the expected content

**Can't find page ID:**
- Use `list_pages` to get current page IDs
- Ensure page wasn't closed
- Check if new_page succeeded

**Navigation doesn't complete:**
- Check for redirects
- Verify no JavaScript errors blocking load
- Try waiting for specific element instead of load event
