# Chrome DevTools Performance Reference

Record and analyze performance traces to identify bottlenecks, measure page load times, and get actionable optimization insights.

## Available Tools

### performance_start_trace
Begin recording a performance trace.

**Parameters:**
- `url` (optional): URL to navigate to and trace (starts fresh trace)
- `categories` (optional): Trace categories to capture (default: all relevant)
- `pageId` (optional): Specific page to trace

**Example:**
```
Start trace on current page:
mcp__chrome-devtools__performance_start_trace

Start trace with navigation:
mcp__chrome-devtools__performance_start_trace
  url: https://example.com

Start trace with specific categories:
mcp__chrome-devtools__performance_start_trace
  categories: ["loading", "scripting", "rendering"]

Start trace on specific page:
mcp__chrome-devtools__performance_start_trace
  pageId: page-123
```

**Trace categories:**
- `loading` - Page and resource loading
- `scripting` - JavaScript execution
- `rendering` - Layout, paint, composite
- `painting` - Paint operations
- `gpu` - GPU activity
- `network` - Network activity
- `devtools.timeline` - Full timeline
- `v8.execute` - Detailed V8 execution

**Common use cases:**
- Measuring page load performance
- Profiling user interactions
- Finding rendering bottlenecks
- Analyzing JavaScript execution
- Identifying layout thrashing

---

### performance_stop_trace
Stop the current performance trace and save the data.

**Parameters:**
- `pageId` (optional): Specific page to stop trace on

**Example:**
```
Stop current trace:
mcp__chrome-devtools__performance_stop_trace

Stop trace on specific page:
mcp__chrome-devtools__performance_stop_trace
  pageId: page-123
```

**Returns:**
Trace data including:
- Timeline events
- Frame metrics
- Network timing
- JavaScript execution
- Rendering metrics
- Memory usage

**Common use cases:**
- Completing trace after page load
- Finishing trace after user interaction
- Capturing specific time window

---

### performance_analyze_insight
Analyze a completed trace and get actionable performance recommendations.

**Parameters:**
- `traceData` (optional): Trace data to analyze (uses last trace if not provided)
- `focus` (optional): What to focus on ("loading", "interaction", "rendering", "all")

**Example:**
```
Analyze last trace:
mcp__chrome-devtools__performance_analyze_insight

Analyze with focus on loading:
mcp__chrome-devtools__performance_analyze_insight
  focus: "loading"

Analyze interaction performance:
mcp__chrome-devtools__performance_analyze_insight
  focus: "interaction"

Analyze rendering performance:
mcp__chrome-devtools__performance_analyze_insight
  focus: "rendering"
```

**Returns:**
Performance insights including:
- **Metrics**: Core Web Vitals (LCP, FID, CLS), TTI, FCP, etc.
- **Issues**: Specific problems found (long tasks, layout shifts, etc.)
- **Recommendations**: Actionable fixes with priority
- **Opportunities**: Potential optimizations with estimated impact
- **Resource breakdown**: Time spent by category

**Focus areas:**
- `loading` - Initial page load, resource timing, FCP, LCP
- `interaction` - Responsiveness, FID, long tasks, blocking time
- `rendering` - Paint, layout, CLS, reflows
- `all` - Comprehensive analysis

**Common use cases:**
- Getting optimization priorities
- Understanding performance bottlenecks
- Finding Core Web Vitals issues
- Identifying render-blocking resources
- Discovering long tasks

---

## Performance Workflows

### Basic Performance Analysis
```
1. Start tracing:
   mcp__chrome-devtools__performance_start_trace
     url: https://example.com

2. Wait for page load:
   mcp__chrome-devtools__wait_for
     condition: networkidle

3. Stop tracing:
   mcp__chrome-devtools__performance_stop_trace

4. Get insights:
   mcp__chrome-devtools__performance_analyze_insight
```

### Interaction Performance Testing
```
1. Navigate to page:
   mcp__chrome-devtools__navigate_page
     url: https://app.example.com

2. Wait for ready:
   mcp__chrome-devtools__wait_for
     condition: networkidle

3. Start trace:
   mcp__chrome-devtools__performance_start_trace

4. Perform interaction:
   mcp__chrome-devtools__click
     selector: "#heavy-operation-button"

5. Wait for completion:
   mcp__chrome-devtools__wait_for
     condition: "#result"

6. Stop trace:
   mcp__chrome-devtools__performance_stop_trace

7. Analyze interaction performance:
   mcp__chrome-devtools__performance_analyze_insight
     focus: "interaction"
```

### Page Load Optimization
```
1. Start trace with URL:
   mcp__chrome-devtools__performance_start_trace
     url: https://example.com

2. Wait for load:
   mcp__chrome-devtools__wait_for
     condition: networkidle

3. Stop trace:
   mcp__chrome-devtools__performance_stop_trace

4. Get loading insights:
   mcp__chrome-devtools__performance_analyze_insight
     focus: "loading"

5. Implement recommendations

6. Re-test to measure improvement
```

### Rendering Performance Analysis
```
1. Navigate to page:
   mcp__chrome-devtools__navigate_page
     url: https://app.example.com

2. Start trace:
   mcp__chrome-devtools__performance_start_trace

3. Trigger animation/scroll:
   mcp__chrome-devtools__evaluate_script
     script: "window.scrollTo(0, document.body.scrollHeight)"

4. Wait a bit:
   mcp__chrome-devtools__wait_for
     condition: networkidle

5. Stop trace:
   mcp__chrome-devtools__performance_stop_trace

6. Analyze rendering:
   mcp__chrome-devtools__performance_analyze_insight
     focus: "rendering"
```

### Before/After Comparison
```
1. Baseline test:
   - Start trace with URL
   - Wait for complete load
   - Stop trace
   - Analyze and save results

2. Make optimizations

3. Comparison test:
   - Start trace with URL
   - Wait for complete load
   - Stop trace
   - Analyze and compare metrics
```

---

## Performance Metrics

### Core Web Vitals

**LCP (Largest Contentful Paint):**
- Good: < 2.5s
- Needs improvement: 2.5s - 4.0s
- Poor: > 4.0s
- Measures: Loading performance

**FID (First Input Delay):**
- Good: < 100ms
- Needs improvement: 100ms - 300ms
- Poor: > 300ms
- Measures: Interactivity

**CLS (Cumulative Layout Shift):**
- Good: < 0.1
- Needs improvement: 0.1 - 0.25
- Poor: > 0.25
- Measures: Visual stability

### Other Important Metrics

**FCP (First Contentful Paint):**
- Good: < 1.8s
- Measures: When first content appears

**TTI (Time to Interactive):**
- Good: < 3.8s
- Measures: When page becomes fully interactive

**TBT (Total Blocking Time):**
- Good: < 200ms
- Measures: Sum of long task blocking time

**Speed Index:**
- Good: < 3.4s
- Measures: How quickly content is visually displayed

---

## Best Practices

1. **Test with realistic conditions** - Use network/CPU throttling
2. **Multiple test runs** - Performance varies, test 3-5 times
3. **Test on real devices** - Mobile performance often differs
4. **Focus on user journey** - Trace critical user paths
5. **Set performance budgets** - Define acceptable metric targets
6. **Test after changes** - Verify optimizations work
7. **Use appropriate focus** - Target specific performance aspects
8. **Clear cache between tests** - Test first-time visitor experience

---

## Common Patterns

### Complete Performance Audit Pattern
```
start_trace(url) → wait(networkidle) → stop_trace →
analyze_insight(all) → review recommendations
```

### Interaction Testing Pattern
```
navigate → wait → start_trace →
interact → wait → stop_trace →
analyze_insight(interaction)
```

### Optimization Verification Pattern
```
baseline test → analyze → implement fixes →
new test → compare metrics → verify improvement
```

---

## Trace Categories Explained

**loading:**
- Resource loading events
- Parse HTML/CSS
- Network requests
- Cache hits/misses

**scripting:**
- JavaScript execution
- Function calls
- Garbage collection
- V8 compilation

**rendering:**
- Layout calculations
- Paint operations
- Compositing
- Layer creation

**painting:**
- Paint rectangles
- Rasterization
- GPU upload

**network:**
- Request/response timing
- Connection setup
- Data transfer

---

## Performance Issues & Solutions

### Long Tasks (> 50ms)
**Problem:** JavaScript blocking main thread
**Solutions:**
- Code splitting
- Web Workers
- Async/defer scripts
- Reduce JavaScript payload

### Layout Thrashing
**Problem:** Forced synchronous layouts
**Solutions:**
- Batch DOM reads/writes
- Use requestAnimationFrame
- Avoid layout-triggering properties in loops

### Large Largest Contentful Paint
**Problem:** Critical resources load slowly
**Solutions:**
- Optimize images
- Preload critical resources
- Remove render-blocking resources
- Use CDN

### High Cumulative Layout Shift
**Problem:** Elements shifting during load
**Solutions:**
- Set image dimensions
- Reserve space for ads/embeds
- Avoid inserting content above existing content
- Use transform for animations

### Slow First Input Delay
**Problem:** Page not responsive to input
**Solutions:**
- Break up long tasks
- Defer non-critical JavaScript
- Use web workers
- Optimize event handlers

---

## Reading Trace Results

### Timeline Events
- **Frame**: Visual frame rendered
- **Task**: Main thread work
- **Animation**: Animation frame
- **Event**: User input event
- **Paint**: Paint operation
- **Layout**: Layout calculation
- **Compile**: JavaScript compilation
- **Evaluate**: JavaScript execution

### Performance Markers
- **FCP**: First paint with content
- **LCP**: Largest element painted
- **TTI**: Page becomes interactive
- **Long Task**: Task > 50ms

### Resource Types
- **Document**: HTML page
- **Script**: JavaScript files
- **Stylesheet**: CSS files
- **Image**: Images
- **Font**: Web fonts
- **XHR/Fetch**: API requests

---

## Troubleshooting

**Trace doesn't capture expected events:**
- Ensure correct categories are enabled
- Check if trace duration was long enough
- Verify page actually performed the action

**Metrics seem inaccurate:**
- Run multiple tests for consistency
- Check network conditions
- Verify page loaded completely
- Clear cache if testing fresh load

**Analysis shows no issues but page feels slow:**
- Test on slower devices/networks
- Check for issues not covered by metrics
- Test different user flows
- Monitor real user metrics (RUM)

**Can't reproduce performance issue:**
- Check if issue is device/network specific
- Test with different browser profiles
- Clear cache and cookies
- Check for race conditions
