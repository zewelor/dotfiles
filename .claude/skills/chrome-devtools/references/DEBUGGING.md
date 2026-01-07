# Chrome DevTools Debugging Reference

Access console logs, inspect network requests, execute JavaScript, and gather debugging information.

## Available Tools

### list_console_messages
Retrieve all console messages (logs, warnings, errors) from the page.

**Parameters:**
- `pageId` (optional): Specific page to get console messages from
- `types` (optional): Filter by message type (["log", "warn", "error", "info"])

**Example:**
```
Get all console messages:
mcp__chrome-devtools__list_console_messages

Get only errors:
mcp__chrome-devtools__list_console_messages
  types: ["error"]

Get warnings and errors:
mcp__chrome-devtools__list_console_messages
  types: ["warn", "error"]

Get from specific page:
mcp__chrome-devtools__list_console_messages
  pageId: page-123
```

**Returns:**
Array of console message objects with:
- `type`: Message type (log, warn, error, info)
- `text`: Message content
- `timestamp`: When the message occurred
- `source`: Where it came from
- `stackTrace`: Stack trace for errors

**Common use cases:**
- Checking for JavaScript errors
- Verifying debug output
- Monitoring warnings
- Debugging application flow
- Catching exceptions

---

### get_console_message
Retrieve a specific console message by ID or index.

**Parameters:**
- `messageId` (required): The ID or index of the message
- `pageId` (optional): Specific page

**Example:**
```
Get specific message:
mcp__chrome-devtools__get_console_message
  messageId: msg-123

Get message from specific page:
mcp__chrome-devtools__get_console_message
  messageId: msg-456
  pageId: page-123
```

**Returns:**
Detailed message object with:
- Full message text
- Stack trace (if error)
- Source location
- Arguments/parameters

**Common use cases:**
- Getting detailed error information
- Examining specific log entries
- Debugging specific console output

---

### list_network_requests
View all network requests made by the page.

**Parameters:**
- `pageId` (optional): Specific page to get requests from
- `filter` (optional): Filter by URL pattern, method, or status

**Example:**
```
Get all requests:
mcp__chrome-devtools__list_network_requests

Get API requests only:
mcp__chrome-devtools__list_network_requests
  filter: "/api/"

Get failed requests:
mcp__chrome-devtools__list_network_requests
  filter: "status:4xx,5xx"

Get from specific page:
mcp__chrome-devtools__list_network_requests
  pageId: page-123
```

**Returns:**
Array of network request objects with:
- `requestId`: Unique identifier
- `url`: Request URL
- `method`: HTTP method (GET, POST, etc.)
- `status`: Response status code
- `statusText`: Status message
- `type`: Resource type (xhr, fetch, script, stylesheet, image, etc.)
- `timing`: Performance timing data
- `size`: Response size

**Common use cases:**
- Debugging API calls
- Finding failed requests
- Analyzing network performance
- Verifying request/response data
- Tracking resource loading

---

### get_network_request
Get detailed information about a specific network request.

**Parameters:**
- `requestId` (required): The ID of the request
- `pageId` (optional): Specific page

**Example:**
```
Get request details:
mcp__chrome-devtools__get_network_request
  requestId: req-123

Get from specific page:
mcp__chrome-devtools__get_network_request
  requestId: req-456
  pageId: page-123
```

**Returns:**
Detailed request object with:
- Full request headers
- Request payload/body
- Response headers
- Response body
- Timing breakdown
- Cookies
- Security details

**Common use cases:**
- Inspecting request headers
- Viewing request/response payloads
- Debugging authentication issues
- Analyzing timing/performance
- Checking cookies and security

---

### evaluate_script
Execute JavaScript code in the page context.

**Parameters:**
- `script` (required): JavaScript code to execute
- `returnByValue` (optional): Whether to return the result value
- `pageId` (optional): Specific page to execute on

**Example:**
```
Get page title:
mcp__chrome-devtools__evaluate_script
  script: "document.title"
  returnByValue: true

Execute function:
mcp__chrome-devtools__evaluate_script
  script: |
    function getFormData() {
      const form = document.querySelector('#myForm');
      return new FormData(form);
    }
    getFormData();
  returnByValue: true

Modify DOM:
mcp__chrome-devtools__evaluate_script
  script: |
    document.querySelector('#status').textContent = 'Ready';

Get computed styles:
mcp__chrome-devtools__evaluate_script
  script: |
    const el = document.querySelector('#target');
    window.getComputedStyle(el).backgroundColor;
  returnByValue: true

Check for errors:
mcp__chrome-devtools__evaluate_script
  script: |
    window.hasErrors = typeof window.onerror !== 'undefined';
    window.hasErrors;
  returnByValue: true
```

**Common use cases:**
- Querying DOM state
- Extracting data from the page
- Testing JavaScript functions
- Modifying page state
- Running diagnostic scripts
- Checking global variables

---

## Debugging Workflows

### Error Investigation Workflow
```
1. Check for console errors:
   mcp__chrome-devtools__list_console_messages
     types: ["error"]

2. Get detailed error info:
   mcp__chrome-devtools__get_console_message
     messageId: <error-id>

3. Check related network failures:
   mcp__chrome-devtools__list_network_requests
     filter: "status:4xx,5xx"

4. Execute diagnostic script:
   mcp__chrome-devtools__evaluate_script
     script: "console.log('Current state:', appState)"
```

### API Debugging Workflow
```
1. Navigate to page:
   mcp__chrome-devtools__navigate_page
     url: https://app.example.com

2. Trigger API call (interact with page)

3. List all API requests:
   mcp__chrome-devtools__list_network_requests
     filter: "/api/"

4. Inspect failed request:
   mcp__chrome-devtools__get_network_request
     requestId: req-123

5. Verify request payload and headers
```

### Performance Debugging Workflow
```
1. Start fresh navigation:
   mcp__chrome-devtools__navigate_page
     url: https://example.com

2. Wait for page load:
   mcp__chrome-devtools__wait_for
     condition: networkidle

3. Get all network requests:
   mcp__chrome-devtools__list_network_requests

4. Identify slow requests (sort by timing)

5. Get details of slow request:
   mcp__chrome-devtools__get_network_request
     requestId: slow-req-id

6. Analyze timing breakdown
```

### State Inspection Workflow
```
1. Navigate to page:
   mcp__chrome-devtools__navigate_page
     url: https://app.example.com

2. Interact with application

3. Query application state:
   mcp__chrome-devtools__evaluate_script
     script: |
       JSON.stringify({
         user: window.currentUser,
         route: window.location.pathname,
         errors: window.errors || []
       })
     returnByValue: true

4. Check console for issues:
   mcp__chrome-devtools__list_console_messages
```

### Form Validation Debugging
```
1. Fill form with test data:
   mcp__chrome-devtools__fill_form
     fields: {...}

2. Submit form:
   mcp__chrome-devtools__click
     selector: "button[type='submit']"

3. Check console for validation errors:
   mcp__chrome-devtools__list_console_messages
     types: ["error", "warn"]

4. Inspect form state:
   mcp__chrome-devtools__evaluate_script
     script: |
       const form = document.querySelector('form');
       ({
         isValid: form.checkValidity(),
         errors: [...form.querySelectorAll(':invalid')]
           .map(el => el.name)
       })
     returnByValue: true
```

---

## Best Practices

1. **Check console early and often** - Errors appear as soon as they occur
2. **Filter console messages** - Focus on errors/warnings when debugging
3. **Use evaluate_script for queries** - Better than trying to parse HTML
4. **Inspect network for API issues** - Don't guess at network problems
5. **Return values when executing scripts** - Set `returnByValue: true`
6. **Combine debugging tools** - Console + network + scripts = complete picture
7. **Clear console between tests** - Navigate away to reset console state
8. **Use try-catch in scripts** - Handle potential errors in evaluated code

---

## Common Patterns

### Error Detection Pattern
```
list_console_messages(types: ["error"]) →
if errors exist → get_console_message → investigate
```

### API Verification Pattern
```
trigger action → list_network_requests(filter: "/api/") →
verify status codes → get_network_request(failed) → debug
```

### State Inspection Pattern
```
evaluate_script(query state) →
parse result →
verify expectations
```

### Comprehensive Debug Pattern
```
check console → check network → execute diagnostic scripts →
take screenshot → report findings
```

---

## Script Patterns

### Query DOM Elements
```javascript
// Find elements
document.querySelectorAll('.class-name').length

// Check visibility
document.querySelector('#element').offsetParent !== null

// Get text content
document.querySelector('#target').textContent

// Check attributes
document.querySelector('input').value
```

### Extract Data
```javascript
// Get all links
[...document.querySelectorAll('a')].map(a => ({
  href: a.href,
  text: a.textContent
}))

// Get form data
Object.fromEntries(new FormData(document.querySelector('form')))

// Get table data
[...document.querySelectorAll('table tr')].map(row =>
  [...row.querySelectorAll('td')].map(cell => cell.textContent)
)
```

### Check Application State
```javascript
// Global state
window.appState || window.__STATE__ || {}

// React DevTools
window.__REACT_DEVTOOLS_GLOBAL_HOOK__

// Vue DevTools
window.__VUE_DEVTOOLS_GLOBAL_HOOK__

// Check for errors
window.hasOwnProperty('onerror')
```

### Performance Checks
```javascript
// Check resource timing
performance.getEntriesByType('resource')
  .filter(r => r.duration > 1000)

// Check navigation timing
performance.getEntriesByType('navigation')[0]

// Memory usage (if available)
performance.memory
```

---

## Network Request Filtering

**By URL pattern:**
```
filter: "/api/users"       // Contains this path
filter: "api"              // Contains "api"
filter: "*.jpg"            // Images
```

**By status:**
```
filter: "status:200"       // Successful
filter: "status:4xx"       // Client errors
filter: "status:5xx"       // Server errors
filter: "status:4xx,5xx"   // All errors
```

**By method:**
```
filter: "method:POST"
filter: "method:GET"
filter: "method:PUT,DELETE"
```

**By type:**
```
filter: "type:xhr"         // AJAX requests
filter: "type:fetch"       // Fetch API
filter: "type:script"      // JavaScript files
filter: "type:stylesheet"  // CSS files
```

---

## Troubleshooting

**No console messages:**
- Check if page has actually loaded
- Verify console is not being cleared by page
- Try navigating again to reset state

**Can't see network requests:**
- Ensure requests happened after opening DevTools
- Try navigating to page with fresh start
- Check if requests are being filtered out

**Script evaluation fails:**
- Check for syntax errors in script
- Verify page context is correct
- Try simpler script first to test
- Use try-catch in script

**Network request details incomplete:**
- Some requests may not have response bodies
- Cached resources may have limited info
- CORS may block some details

**State queries return unexpected results:**
- Verify timing - state may change after query
- Check if application uses different state storage
- Try multiple approaches to access state
