# Chrome DevTools Interaction Reference

Interact with page elements through clicks, keyboard input, form filling, drag operations, and file uploads.

## Available Tools

### click
Click on page elements.

**Parameters:**
- `selector` (required): CSS selector for the element to click
- `button` (optional): Which mouse button ("left", "right", "middle")
- `clickCount` (optional): Number of clicks (1, 2 for double-click)
- `pageId` (optional): Specific page to operate on

**Example:**
```
Single click:
mcp__chrome-devtools__click
  selector: "#submit-button"

Double click:
mcp__chrome-devtools__click
  selector: ".editable-field"
  clickCount: 2

Right click:
mcp__chrome-devtools__click
  selector: "#context-menu-trigger"
  button: right

Click on specific page:
mcp__chrome-devtools__click
  selector: "button[type='submit']"
  pageId: page-123
```

**Common use cases:**
- Submitting forms
- Opening dropdowns
- Triggering navigation
- Activating buttons
- Opening context menus

---

### fill
Enter text into form fields.

**Parameters:**
- `selector` (required): CSS selector for the input field
- `value` (required): Text to enter
- `pageId` (optional): Specific page to operate on

**Example:**
```
Fill text input:
mcp__chrome-devtools__fill
  selector: "#username"
  value: "testuser@example.com"

Fill password:
mcp__chrome-devtools__fill
  selector: "input[type='password']"
  value: "SecurePass123"

Fill textarea:
mcp__chrome-devtools__fill
  selector: "#comment-box"
  value: "This is my feedback..."
```

**Common use cases:**
- Entering form data
- Filling login credentials
- Entering search queries
- Populating text areas

---

### fill_form
Fill multiple form fields at once.

**Parameters:**
- `fields` (required): Object mapping selectors to values
- `pageId` (optional): Specific page to operate on

**Example:**
```
Fill entire login form:
mcp__chrome-devtools__fill_form
  fields: {
    "#username": "user@example.com",
    "#password": "SecurePass123",
    "#remember-me": "true"
  }

Fill registration form:
mcp__chrome-devtools__fill_form
  fields: {
    "input[name='firstName']": "John",
    "input[name='lastName']": "Doe",
    "input[name='email']": "john@example.com",
    "select[name='country']": "USA"
  }
```

**Common use cases:**
- Completing multi-field forms efficiently
- Registration flows
- Checkout processes
- Settings/preferences forms

---

### press_key
Simulate keyboard input.

**Parameters:**
- `key` (required): Key to press (e.g., "Enter", "Tab", "Escape", "a", "ArrowDown")
- `modifiers` (optional): Array of modifier keys (["Control"], ["Shift"], ["Meta"])
- `pageId` (optional): Specific page to operate on

**Example:**
```
Press Enter:
mcp__chrome-devtools__press_key
  key: Enter

Press Tab:
mcp__chrome-devtools__press_key
  key: Tab

Ctrl+A (select all):
mcp__chrome-devtools__press_key
  key: a
  modifiers: ["Control"]

Cmd+V (paste on Mac):
mcp__chrome-devtools__press_key
  key: v
  modifiers: ["Meta"]

Arrow navigation:
mcp__chrome-devtools__press_key
  key: ArrowDown
```

**Common key names:**
- Special: `Enter`, `Tab`, `Escape`, `Backspace`, `Delete`
- Arrows: `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`
- Modifiers: `Control`, `Shift`, `Alt`, `Meta` (Cmd on Mac)
- Function: `F1` through `F12`
- Letters/numbers: Use the character directly

**Common use cases:**
- Submitting forms (Enter)
- Navigating fields (Tab)
- Keyboard shortcuts
- Dismissing dialogs (Escape)
- Dropdown navigation (Arrow keys)

---

### hover
Move the mouse cursor over elements.

**Parameters:**
- `selector` (required): CSS selector for the element to hover over
- `pageId` (optional): Specific page to operate on

**Example:**
```
Hover over menu item:
mcp__chrome-devtools__hover
  selector: "#dropdown-trigger"

Hover to reveal tooltip:
mcp__chrome-devtools__hover
  selector: ".info-icon"

Hover over navigation:
mcp__chrome-devtools__hover
  selector: "nav .menu-item"
```

**Common use cases:**
- Revealing dropdowns
- Triggering tooltips
- Activating hover effects
- Testing interactive states
- Revealing hidden menus

---

### drag
Perform drag and drop operations.

**Parameters:**
- `sourceSelector` (required): Element to drag from
- `targetSelector` (required): Element to drag to
- `pageId` (optional): Specific page to operate on

**Example:**
```
Drag file to upload zone:
mcp__chrome-devtools__drag
  sourceSelector: "#file-item"
  targetSelector: "#drop-zone"

Reorder list items:
mcp__chrome-devtools__drag
  sourceSelector: ".list-item:nth-child(1)"
  targetSelector: ".list-item:nth-child(3)"

Drag to trash:
mcp__chrome-devtools__drag
  sourceSelector: "#document-123"
  targetSelector: "#trash-bin"
```

**Common use cases:**
- File uploads via drag-drop
- Reordering lists
- Kanban board operations
- Interactive games/puzzles
- Visual editors

---

### upload_file
Handle file upload inputs.

**Parameters:**
- `selector` (required): CSS selector for file input
- `filePath` (required): Absolute path to file to upload
- `pageId` (optional): Specific page to operate on

**Example:**
```
Upload single file:
mcp__chrome-devtools__upload_file
  selector: "input[type='file']"
  filePath: "/Users/john/documents/report.pdf"

Upload to specific input:
mcp__chrome-devtools__upload_file
  selector: "#profile-picture"
  filePath: "/Users/john/pictures/avatar.jpg"
```

**Common use cases:**
- Uploading documents
- Changing profile pictures
- Attaching files to forms
- Bulk file uploads
- Image uploads

---

### handle_dialog
Respond to browser dialogs (alerts, confirms, prompts).

**Parameters:**
- `action` (required): "accept" or "dismiss"
- `promptText` (optional): Text to enter in prompt dialogs
- `pageId` (optional): Specific page to operate on

**Example:**
```
Accept alert:
mcp__chrome-devtools__handle_dialog
  action: accept

Dismiss confirmation:
mcp__chrome-devtools__handle_dialog
  action: dismiss

Respond to prompt:
mcp__chrome-devtools__handle_dialog
  action: accept
  promptText: "My response"
```

**Common use cases:**
- Accepting confirmations
- Dismissing alerts
- Responding to prompts
- Handling before-unload dialogs

---

## Interaction Workflows

### Form Submission Workflow
```
1. Fill form fields:
   mcp__chrome-devtools__fill_form
     fields: {
       "#email": "user@example.com",
       "#password": "pass123"
     }

2. Submit form:
   mcp__chrome-devtools__click
     selector: "button[type='submit']"

3. Wait for navigation/response:
   mcp__chrome-devtools__wait_for
     condition: networkidle

4. Verify success:
   mcp__chrome-devtools__take_screenshot
```

### Search Workflow
```
1. Focus search field:
   mcp__chrome-devtools__click
     selector: "#search-input"

2. Enter search term:
   mcp__chrome-devtools__fill
     selector: "#search-input"
     value: "test query"

3. Submit search:
   mcp__chrome-devtools__press_key
     key: Enter

4. Wait for results:
   mcp__chrome-devtools__wait_for
     condition: ".search-results"
```

### Dropdown Navigation Workflow
```
1. Hover over menu:
   mcp__chrome-devtools__hover
     selector: "#main-menu"

2. Wait for dropdown:
   mcp__chrome-devtools__wait_for
     condition: "#dropdown-menu"

3. Click submenu item:
   mcp__chrome-devtools__click
     selector: "#dropdown-menu a[href='/settings']"
```

### File Upload Workflow
```
1. Navigate to upload page:
   mcp__chrome-devtools__navigate_page
     url: https://example.com/upload

2. Upload file:
   mcp__chrome-devtools__upload_file
     selector: "input[type='file']"
     filePath: "/path/to/file.pdf"

3. Wait for upload processing:
   mcp__chrome-devtools__wait_for
     condition: ".upload-success"

4. Verify upload:
   mcp__chrome-devtools__take_screenshot
```

### Keyboard Navigation Workflow
```
1. Press Tab to navigate:
   mcp__chrome-devtools__press_key
     key: Tab

2. Select option with Enter:
   mcp__chrome-devtools__press_key
     key: Enter

3. Navigate dropdown with arrows:
   mcp__chrome-devtools__press_key
     key: ArrowDown
```

---

## Best Practices

1. **Wait before interacting** - Ensure elements are ready before clicking/filling
2. **Use specific selectors** - Avoid ambiguous selectors that match multiple elements
3. **Verify element visibility** - Elements must be visible and clickable
4. **Handle dynamic content** - Wait for AJAX/dynamic content to load
5. **Use fill_form for efficiency** - Batch form fills instead of multiple fill calls
6. **Clear fields before filling** - Some fields may have default values
7. **Handle dialogs promptly** - Dialogs can block other operations
8. **Test selectors first** - Verify selectors match expected elements

---

## Common Patterns

### Safe Click Pattern
```
wait_for(selector) → click(selector) → wait_for(result)
```

### Form Fill Pattern
```
fill_form → click(submit) → wait_for(networkidle) → verify
```

### Keyboard Shortcut Pattern
```
press_key(key, modifiers) → wait_for(result)
```

### Hover-Click Pattern
```
hover(trigger) → wait_for(menu) → click(item)
```

---

## Selector Tips

**Good selectors:**
- `#unique-id` - IDs are best (unique)
- `[data-testid='submit']` - Test IDs are reliable
- `button[type='submit']` - Specific attributes
- `.form-group input[name='email']` - Scoped selectors

**Avoid:**
- `.btn` - Too generic
- `div:nth-child(5)` - Fragile to DOM changes
- `body > div > div > span` - Overly specific path
- Relying on text content (use data attributes instead)

---

## Troubleshooting

**Element not found:**
- Verify selector is correct
- Wait for element to appear in DOM
- Check if element is in iframe
- Use `list_console_messages` for JS errors

**Click doesn't work:**
- Ensure element is visible and clickable
- Check for overlaying elements
- Wait for page to be fully loaded
- Try scrolling element into view first

**Fill doesn't work:**
- Verify input is not disabled
- Check for readonly attribute
- Ensure field accepts text input
- Try clicking field first to focus

**Upload fails:**
- Verify file path is absolute and correct
- Check file exists and is readable
- Ensure selector targets file input
- Verify input accepts the file type

**Dialog not handled:**
- Set up handler before triggering action
- Check if dialog actually appears
- Verify action type (accept vs dismiss)
- Test with simple alert first
