# Chrome DevTools Emulation Reference

Simulate different devices, network conditions, CPU throttling, and viewport sizes to test responsive designs and performance under various constraints.

## Available Tools

### emulate
Simulate different device types, network conditions, and user agents.

**Parameters:**
- `device` (optional): Device preset name (e.g., "iPhone 13", "iPad Pro", "Galaxy S21")
- `network` (optional): Network condition preset ("offline", "slow-3g", "fast-3g", "4g")
- `userAgent` (optional): Custom user agent string
- `viewport` (optional): Viewport dimensions object `{width, height, deviceScaleFactor, isMobile}`
- `geolocation` (optional): GPS coordinates `{latitude, longitude, accuracy}`
- `cpuThrottling` (optional): CPU throttling multiplier (e.g., 4 = 4x slowdown)
- `pageId` (optional): Specific page to apply emulation to

**Example:**
```
Emulate iPhone 13:
mcp__chrome-devtools__emulate
  device: "iPhone 13"

Emulate slow network:
mcp__chrome-devtools__emulate
  network: "slow-3g"

Emulate custom device:
mcp__chrome-devtools__emulate
  viewport: {
    width: 375,
    height: 667,
    deviceScaleFactor: 2,
    isMobile: true
  }

Emulate slow CPU (4x slowdown):
mcp__chrome-devtools__emulate
  cpuThrottling: 4

Emulate location:
mcp__chrome-devtools__emulate
  geolocation: {
    latitude: 37.7749,
    longitude: -122.4194,
    accuracy: 100
  }

Combine emulations:
mcp__chrome-devtools__emulate
  device: "iPhone 13"
  network: "fast-3g"
  cpuThrottling: 2

Custom user agent:
mcp__chrome-devtools__emulate
  userAgent: "Mozilla/5.0 (custom bot)"
```

**Device Presets:**
- **Mobile**: "iPhone 13", "iPhone 13 Pro Max", "iPhone SE", "Pixel 5", "Pixel 7", "Galaxy S21", "Galaxy S20 Ultra"
- **Tablet**: "iPad", "iPad Pro 11", "iPad Pro 12.9", "Galaxy Tab S8"
- **Desktop**: "Laptop with touch", "Laptop with HiDPI", "Desktop 1080p", "Desktop 4K"

**Network Presets:**
- `offline` - No connectivity
- `slow-3g` - Slow 3G (400ms RTT, 400kbps down, 400kbps up)
- `fast-3g` - Fast 3G (150ms RTT, 1.6Mbps down, 750kbps up)
- `4g` - 4G (50ms RTT, 4Mbps down, 3Mbps up)
- `wifi` - WiFi (10ms RTT, 30Mbps down, 15Mbps up)
- `custom` - Define custom latency/throughput

**CPU Throttling:**
- `1` - No throttling (default)
- `2` - 2x slowdown
- `4` - 4x slowdown (common for low-end mobile)
- `6` - 6x slowdown (very slow devices)

**Common use cases:**
- Testing mobile responsiveness
- Simulating slow networks
- Testing on low-end devices
- Geolocation-based features
- User agent detection
- Touch interface testing

---

### resize_page
Adjust viewport dimensions without full device emulation.

**Parameters:**
- `width` (required): Viewport width in pixels
- `height` (required): Viewport height in pixels
- `deviceScaleFactor` (optional): Pixel density (default: 1)
- `pageId` (optional): Specific page to resize

**Example:**
```
Standard mobile size:
mcp__chrome-devtools__resize_page
  width: 375
  height: 667

Tablet size:
mcp__chrome-devtools__resize_page
  width: 768
  height: 1024

Desktop size:
mcp__chrome-devtools__resize_page
  width: 1920
  height: 1080

With retina density:
mcp__chrome-devtools__resize_page
  width: 375
  height: 667
  deviceScaleFactor: 2

Specific page:
mcp__chrome-devtools__resize_page
  width: 1024
  height: 768
  pageId: page-123
```

**Common viewport sizes:**
- Mobile portrait: 375x667, 360x640, 414x896
- Mobile landscape: 667x375, 896x414, 812x375
- Tablet portrait: 768x1024, 834x1194, 1024x1366
- Tablet landscape: 1024x768, 1194x834, 1366x1024
- Desktop: 1366x768, 1920x1080, 2560x1440

**Common use cases:**
- Testing responsive breakpoints
- Verifying layout at specific sizes
- Screenshot at exact dimensions
- Testing media queries
- Checking overflow behavior

---

## Emulation Workflows

### Mobile Testing Workflow
```
1. Emulate mobile device:
   mcp__chrome-devtools__emulate
     device: "iPhone 13"

2. Navigate to page:
   mcp__chrome-devtools__navigate_page
     url: https://example.com

3. Wait for load:
   mcp__chrome-devtools__wait_for
     condition: networkidle

4. Take screenshot:
   mcp__chrome-devtools__take_screenshot

5. Test interactions:
   mcp__chrome-devtools__click
     selector: "#mobile-menu"
```

### Network Performance Testing
```
1. Set slow network:
   mcp__chrome-devtools__emulate
     network: "slow-3g"

2. Start performance trace:
   mcp__chrome-devtools__performance_start_trace
     url: https://example.com

3. Wait for load:
   mcp__chrome-devtools__wait_for
     condition: networkidle

4. Stop trace:
   mcp__chrome-devtools__performance_stop_trace

5. Analyze:
   mcp__chrome-devtools__performance_analyze_insight
     focus: "loading"
```

### Responsive Design Testing
```
1. Test mobile:
   - resize_page(375, 667)
   - navigate, wait, screenshot

2. Test tablet:
   - resize_page(768, 1024)
   - navigate, wait, screenshot

3. Test desktop:
   - resize_page(1920, 1080)
   - navigate, wait, screenshot

4. Compare screenshots
```

### Low-End Device Simulation
```
1. Emulate slow device:
   mcp__chrome-devtools__emulate
     device: "Pixel 5"
     network: "fast-3g"
     cpuThrottling: 4

2. Start trace:
   mcp__chrome-devtools__performance_start_trace
     url: https://app.example.com

3. Wait and interact:
   - wait_for(networkidle)
   - click, fill form, etc.

4. Stop trace:
   mcp__chrome-devtools__performance_stop_trace

5. Analyze interaction performance:
   mcp__chrome-devtools__performance_analyze_insight
     focus: "interaction"
```

### Geolocation Testing
```
1. Set location (San Francisco):
   mcp__chrome-devtools__emulate
     geolocation: {
       latitude: 37.7749,
       longitude: -122.4194,
       accuracy: 100
     }

2. Navigate to location-aware page:
   mcp__chrome-devtools__navigate_page
     url: https://example.com/map

3. Verify location detection:
   mcp__chrome-devtools__evaluate_script
     script: |
       navigator.geolocation.getCurrentPosition(
         pos => pos.coords
       )
     returnByValue: true
```

### Offline Testing
```
1. Set offline mode:
   mcp__chrome-devtools__emulate
     network: "offline"

2. Navigate (will fail):
   mcp__chrome-devtools__navigate_page
     url: https://example.com

3. Check error handling:
   mcp__chrome-devtools__list_console_messages
     types: ["error"]

4. Take screenshot of offline page

5. Go back online:
   mcp__chrome-devtools__emulate
     network: "wifi"

6. Verify recovery
```

---

## Best Practices

1. **Test multiple devices** - Don't rely on single device emulation
2. **Combine CPU and network throttling** - Real-world conditions vary
3. **Test both orientations** - Portrait and landscape
4. **Verify touch targets** - Ensure clickable areas are large enough (44x44px min)
5. **Test with slow networks** - Don't assume fast connections
6. **Check geolocation permissions** - Handle denied permissions
7. **Test offline scenarios** - Verify graceful degradation
8. **Use realistic user agents** - Some sites serve different content
9. **Test at common breakpoints** - 375px, 768px, 1024px, 1920px
10. **Verify device pixel ratio** - Test retina and standard displays

---

## Common Patterns

### Multi-Device Testing Pattern
```
for device in ["iPhone 13", "iPad Pro", "Desktop 1080p"]:
  emulate(device) → navigate → screenshot → verify
```

### Network Condition Testing Pattern
```
for network in ["slow-3g", "fast-3g", "4g"]:
  emulate(network) → start_trace → load page →
  stop_trace → analyze → record metrics
```

### Breakpoint Testing Pattern
```
for width in [375, 768, 1024, 1920]:
  resize_page(width, height) → navigate →
  screenshot → verify layout
```

### Progressive Enhancement Pattern
```
emulate(offline) → verify basic functionality →
emulate(slow-3g) → verify enhanced features →
emulate(wifi) → verify full experience
```

---

## Responsive Breakpoints

### Common CSS Breakpoints
```css
/* Mobile */
@media (max-width: 767px) { }

/* Tablet */
@media (min-width: 768px) and (max-width: 1023px) { }

/* Desktop */
@media (min-width: 1024px) { }

/* Large Desktop */
@media (min-width: 1920px) { }
```

### Test at These Widths
- **320px** - Small mobile (iPhone SE)
- **375px** - Standard mobile (iPhone 13)
- **414px** - Large mobile (iPhone 13 Pro Max)
- **768px** - Tablet portrait (iPad)
- **1024px** - Tablet landscape / small laptop
- **1366px** - Common laptop
- **1920px** - Full HD desktop

---

## Device Specifications

### Popular Mobile Devices

**iPhone 13:**
- Viewport: 390x844
- DPR: 3
- User agent: iOS 15

**iPhone 13 Pro Max:**
- Viewport: 428x926
- DPR: 3
- User agent: iOS 15

**iPhone SE:**
- Viewport: 375x667
- DPR: 2
- User agent: iOS 15

**Pixel 5:**
- Viewport: 393x851
- DPR: 2.75
- User agent: Android 11

**Galaxy S21:**
- Viewport: 360x800
- DPR: 3
- User agent: Android 11

### Tablets

**iPad:**
- Viewport: 768x1024 (portrait)
- DPR: 2
- User agent: iPadOS 15

**iPad Pro 11:**
- Viewport: 834x1194 (portrait)
- DPR: 2
- User agent: iPadOS 15

**iPad Pro 12.9:**
- Viewport: 1024x1366 (portrait)
- DPR: 2
- User agent: iPadOS 15

---

## Network Conditions Details

### Offline
- **Use case**: Testing offline functionality, service workers
- **RTT**: N/A
- **Download**: 0 kbps
- **Upload**: 0 kbps

### Slow 3G
- **Use case**: Poor mobile coverage, developing regions
- **RTT**: 400ms
- **Download**: 400 kbps (50 KB/s)
- **Upload**: 400 kbps (50 KB/s)

### Fast 3G
- **Use case**: Average mobile connection
- **RTT**: 150ms
- **Download**: 1.6 Mbps (200 KB/s)
- **Upload**: 750 kbps (94 KB/s)

### 4G
- **Use case**: Good mobile connection
- **RTT**: 50ms
- **Download**: 4 Mbps (500 KB/s)
- **Upload**: 3 Mbps (375 KB/s)

### WiFi
- **Use case**: Typical home/office WiFi
- **RTT**: 10ms
- **Download**: 30 Mbps (3.75 MB/s)
- **Upload**: 15 Mbps (1.88 MB/s)

---

## CPU Throttling Guide

### 1x (No Throttling)
- Desktop computers
- High-end laptops
- Flagship phones (recent year)

### 2x Throttling
- Mid-range laptops
- Older desktops
- Previous-gen flagship phones

### 4x Throttling
- Low-end laptops
- Budget phones
- Older devices (3+ years)
- Common testing baseline

### 6x Throttling
- Very old devices
- Budget phones (entry-level)
- Extreme testing scenario

---

## Troubleshooting

**Emulation doesn't seem to work:**
- Verify emulation was set before navigation
- Check if site detects server-side (can't be emulated)
- Try refreshing page after setting emulation
- Ensure pageId is correct if specified

**Network throttling not visible:**
- Throttling applies to new requests only
- Clear cache to force new requests
- Verify using list_network_requests to check timing
- Check if site uses service worker (may cache)

**Device emulation doesn't match real device:**
- Browser emulation is approximate
- Test on real device for final verification
- Some features (GPU, sensors) can't be fully emulated
- JavaScript performance differs from real hardware

**Geolocation not working:**
- Check if page requests permission
- Verify geolocation API is used correctly
- Some sites may require HTTPS for geolocation
- Check browser console for permission errors

**Touch events not working:**
- Ensure device emulation sets isMobile: true
- Some sites detect touch differently
- Try actual device for touch-specific features
- Check if site uses pointer events vs touch events
