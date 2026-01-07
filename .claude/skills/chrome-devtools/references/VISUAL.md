# Chrome DevTools Visual Testing Reference

Capture screenshots and DOM snapshots for visual verification, regression testing, and documentation.

## Available Tools

### take_screenshot
Capture a visual screenshot of the current page.

**Parameters:**
- `fullPage` (optional): Capture entire scrollable page (default: false)
- `selector` (optional): Capture only specific element
- `clipArea` (optional): Capture specific rectangle `{x, y, width, height}`
- `omitBackground` (optional): Transparent background (default: false)
- `quality` (optional): JPEG quality 0-100 (default: 80)
- `format` (optional): Image format ("png" or "jpeg", default: "png")
- `pageId` (optional): Specific page to capture

**Example:**
```
Capture viewport:
mcp__chrome-devtools__take_screenshot

Capture full page:
mcp__chrome-devtools__take_screenshot
  fullPage: true

Capture specific element:
mcp__chrome-devtools__take_screenshot
  selector: "#main-content"

Capture specific area:
mcp__chrome-devtools__take_screenshot
  clipArea: {
    x: 0,
    y: 0,
    width: 800,
    height: 600
  }

High quality JPEG:
mcp__chrome-devtools__take_screenshot
  format: "jpeg"
  quality: 95

Transparent background:
mcp__chrome-devtools__take_screenshot
  selector: ".logo"
  omitBackground: true

Specific page:
mcp__chrome-devtools__take_screenshot
  fullPage: true
  pageId: page-123
```

**Returns:**
- Base64-encoded image data
- Image dimensions
- Format information

**Common use cases:**
- Visual regression testing
- Documenting UI states
- Capturing error states
- Creating thumbnails
- Generating reports
- Verifying responsive layouts
- Recording test results

---

### take_snapshot
Capture a DOM snapshot (HTML structure and state).

**Parameters:**
- `selector` (optional): Capture DOM for specific element
- `depth` (optional): How many levels deep to capture (default: all)
- `includeStyles` (optional): Include computed styles (default: false)
- `includeEventListeners` (optional): Include event listener info (default: false)
- `pageId` (optional): Specific page to snapshot

**Example:**
```
Capture full DOM:
mcp__chrome-devtools__take_snapshot

Capture specific element:
mcp__chrome-devtools__take_snapshot
  selector: "#app"

Shallow snapshot:
mcp__chrome-devtools__take_snapshot
  selector: ".container"
  depth: 2

Include computed styles:
mcp__chrome-devtools__take_snapshot
  selector: "#styled-component"
  includeStyles: true

Include event listeners:
mcp__chrome-devtools__take_snapshot
  selector: "#interactive-form"
  includeEventListeners: true

Complete snapshot:
mcp__chrome-devtools__take_snapshot
  includeStyles: true
  includeEventListeners: true
```

**Returns:**
- DOM tree structure
- Element attributes
- Text content
- Computed styles (if requested)
- Event listeners (if requested)

**Common use cases:**
- Debugging DOM issues
- Analyzing element structure
- Comparing DOM states
- Documenting element hierarchy
- Verifying dynamic content
- Checking accessibility tree
- Debugging event handlers

---

## Visual Testing Workflows

### Basic Screenshot Workflow
```
1. Navigate to page:
   mcp__chrome-devtools__navigate_page
     url: https://example.com

2. Wait for content:
   mcp__chrome-devtools__wait_for
     condition: networkidle

3. Take screenshot:
   mcp__chrome-devtools__take_screenshot
     fullPage: true

4. Save/compare screenshot
```

### Element-Specific Screenshot
```
1. Navigate and wait:
   navigate → wait

2. Capture specific element:
   mcp__chrome-devtools__take_screenshot
     selector: "#product-card"

3. Use for component testing
```

### Responsive Visual Testing
```
1. For each viewport size:
   mcp__chrome-devtools__resize_page
     width: <width>
     height: <height>

2. Navigate:
   mcp__chrome-devtools__navigate_page
     url: https://example.com

3. Wait:
   mcp__chrome-devtools__wait_for
     condition: networkidle

4. Screenshot:
   mcp__chrome-devtools__take_screenshot

5. Compare across sizes
```

### Mobile Device Screenshots
```
1. Emulate device:
   mcp__chrome-devtools__emulate
     device: "iPhone 13"

2. Navigate:
   mcp__chrome-devtools__navigate_page
     url: https://example.com

3. Wait:
   mcp__chrome-devtools__wait_for
     condition: networkidle

4. Screenshot:
   mcp__chrome-devtools__take_screenshot

5. Repeat for other devices
```

### Error State Capture
```
1. Navigate to page:
   navigate → wait

2. Trigger error:
   mcp__chrome-devtools__click
     selector: "#trigger-error"

3. Wait for error display:
   mcp__chrome-devtools__wait_for
     condition: ".error-message"

4. Capture error:
   mcp__chrome-devtools__take_screenshot

5. Capture error logs:
   mcp__chrome-devtools__list_console_messages
     types: ["error"]
```

### Form State Capture
```
1. Navigate to form:
   navigate → wait

2. Fill form:
   mcp__chrome-devtools__fill_form
     fields: {...}

3. Take filled state screenshot:
   mcp__chrome-devtools__take_screenshot
     selector: "form"

4. Submit:
   mcp__chrome-devtools__click
     selector: "button[type='submit']"

5. Take success/error screenshot:
   mcp__chrome-devtools__take_screenshot
```

### DOM Comparison Workflow
```
1. Navigate to page:
   navigate → wait

2. Capture initial DOM:
   mcp__chrome-devtools__take_snapshot
     selector: "#dynamic-content"

3. Perform action:
   mcp__chrome-devtools__click
     selector: "#load-more"

4. Wait for update:
   wait_for(condition)

5. Capture updated DOM:
   mcp__chrome-devtools__take_snapshot
     selector: "#dynamic-content"

6. Compare snapshots
```

### Interactive State Documentation
```
1. Capture default state:
   take_screenshot(selector: "#component")

2. Trigger hover state:
   mcp__chrome-devtools__hover
     selector: "#component"

3. Capture hover state:
   take_screenshot(selector: "#component")

4. Trigger active state:
   click → screenshot

5. Document all states
```

---

## Best Practices

1. **Wait before screenshots** - Ensure content is fully loaded
2. **Use fullPage for layout testing** - Captures entire scroll area
3. **Use selector for components** - Focus on specific UI elements
4. **Consistent viewport sizes** - For comparison screenshots
5. **Clear backgrounds** - Use omitBackground for logos/icons
6. **High quality for documentation** - Use quality: 95+ for JPEGs
7. **PNG for UI elements** - Better for text and sharp edges
8. **JPEG for photos** - Smaller file size
9. **Wait after interactions** - Animations need to complete
10. **Capture error states** - Document failure scenarios

---

## Common Patterns

### Visual Regression Testing Pattern
```
baseline: screenshot → save
test: screenshot → compare with baseline → report differences
```

### Multi-State Component Pattern
```
for state in [default, hover, active, disabled]:
  set state → screenshot → document
```

### Responsive Screenshots Pattern
```
for size in breakpoints:
  resize → navigate → wait → screenshot → save
```

### Before/After Pattern
```
screenshot(before) → make changes → screenshot(after) → compare
```

---

## Screenshot Configuration

### Format Selection

**PNG (default):**
- Lossless compression
- Best for: UI elements, text, diagrams
- Supports transparency
- Larger file size

**JPEG:**
- Lossy compression
- Best for: Photos, complex images
- Smaller file size
- No transparency
- Use quality: 80-95

### Quality Settings

**Low (60-70):**
- Very small files
- Visible compression artifacts
- Use for: Previews, thumbnails

**Medium (80-85):**
- Good balance
- Minimal artifacts
- Use for: Most screenshots

**High (90-95):**
- Excellent quality
- Larger files
- Use for: Documentation, archival

**Maximum (100):**
- No compression loss
- Very large files
- Use for: Critical comparisons

---

## Capture Strategies

### Full Page Capture
```
Best for:
- Landing pages
- Marketing pages
- Documentation
- Portfolio sites

Considerations:
- Large file sizes
- Long render time
- May miss lazy-loaded content
```

### Viewport Capture
```
Best for:
- Above-fold content
- Quick previews
- Fast testing
- Consistent sizing

Considerations:
- Misses below-fold content
- Faster rendering
- Smaller files
```

### Element Capture
```
Best for:
- Component testing
- Specific UI elements
- Focused comparisons
- Documentation

Considerations:
- Requires stable selectors
- May need scroll-into-view
- Precise targeting
```

### Clipped Area Capture
```
Best for:
- Specific regions
- Cropped screenshots
- Exact dimensions
- Banner/header images

Considerations:
- Exact pixel coordinates needed
- Absolute positioning
- No auto-sizing
```

---

## DOM Snapshot Use Cases

### Debugging Dynamic Content
```
Capture before/after DOM states to identify:
- Elements added/removed
- Attribute changes
- Class modifications
- Structure changes
```

### Event Listener Debugging
```
Include event listeners to:
- Find duplicate listeners
- Identify missing handlers
- Debug event propagation
- Document interactions
```

### Style Debugging
```
Include computed styles to:
- Check CSS application
- Debug specificity issues
- Verify responsive styles
- Document visual states
```

### Accessibility Analysis
```
Use DOM snapshots to:
- Verify ARIA attributes
- Check semantic HTML
- Validate keyboard navigation
- Document focus order
```

---

## Troubleshooting

**Screenshot is blank:**
- Wait for page load (use wait_for)
- Check if content is hidden
- Verify page navigation completed
- Check console for errors

**Element not captured:**
- Verify selector is correct
- Ensure element is visible
- Check if element needs scroll
- Wait for dynamic content

**Screenshot cut off:**
- Use fullPage: true for full capture
- Check viewport height
- Verify page scroll height
- Wait for lazy-loaded content

**Colors look different:**
- Check browser color profile
- Verify CSS is loaded
- Check for theme/dark mode
- Compare formats (PNG vs JPEG)

**Large file sizes:**
- Use JPEG with quality: 80
- Reduce capture area
- Optimize image dimensions
- Use selector instead of fullPage

**Snapshot missing content:**
- Increase depth parameter
- Wait for dynamic content
- Check shadow DOM elements
- Verify iframe content

**Transparent areas not working:**
- Use PNG format
- Set omitBackground: true
- Verify background is actually transparent
- Check parent container backgrounds
