# UI/UX Design Guide

Rules are priority-ordered. Address higher-priority categories first.

## 1. Accessibility (CRITICAL)

- Color contrast minimum 4.5:1 for normal text, 3:1 for large text
- Visible focus rings on interactive elements — never remove `outline` without a `focus-visible` replacement
- Descriptive `alt` for meaningful images; `alt=""` for decorative
- `aria-label` on icon-only buttons
- Color is never the sole state indicator — pair with icon, text, or border
- Form inputs always have associated `<label>` with `htmlFor`

## 2. Touch & Interaction (CRITICAL)

- Minimum 44x44px touch targets on mobile; comfortable click targets on desktop
- `cursor-pointer` on all clickable elements
- Hover states use color/opacity changes — never `scale` transforms that shift surrounding layout
- Transitions: 150–300ms. Never `transition: all` — list properties explicitly
- Destructive actions require confirmation dialog or undo window — never immediate delete
- Disable submit button and show spinner during async operations; re-enable on error

## 3. Performance (HIGH)

- Explicit `width` and `height` on `<img>` to prevent CLS
- Below-fold images: `loading="lazy"`. Above-fold: `priority` or `fetchpriority="high"`
- Reserve space for async content — use skeleton screens for content-heavy areas, spinners for small actions
- Large lists (>50 items): virtualize
- Honor `prefers-reduced-motion` — disable or reduce animations
- Animate only `transform`/`opacity` (compositor-friendly). Set correct `transform-origin`

## 4. Layout & Responsive (HIGH)

- Minimum 16px body text on mobile
- No horizontal scroll — content fits viewport width
- z-index scale: 10 (dropdowns), 20 (sticky headers), 30 (modals/overlays), 50 (toasts). Never arbitrary values
- Fixed/floating elements must account for their height — content below should not be hidden
- Verify at 375px (mobile), 768px (tablet), 1024px (laptop), 1440px (desktop)
- Text containers: use `truncate`, `line-clamp-*`, or `break-words` for long content
- Flex children need `min-w-0` to allow text truncation

## 5. Typography & Color (MEDIUM)

- Line height 1.5–1.75 for body text
- Line length 65–75 characters max for readability
- `font-variant-numeric: tabular-nums` for number columns and comparisons
- `text-wrap: balance` on short headings, `text-pretty` on longer ones
- Use `…` not `...`; curly quotes not straight quotes
- Loading states end with `…`: "Loading…", "Saving…"

### Tailwind Color Values

| Element | Use | Avoid |
|---------|-----|-------|
| Body text | `text-slate-900` | `text-slate-400` (fails contrast) |
| Muted/secondary text | `text-slate-600` minimum | `text-gray-400` or lighter |
| Borders | `border-gray-200` | Near-invisible borders |
| Glass/frosted cards | `bg-white/80` or higher | `bg-white/10` (too transparent) |
| Hover highlight | `hover:bg-slate-50` or `hover:bg-slate-100` | `hover:scale-105` (shifts layout) |

## 6. Animation (MEDIUM)

- Interruptible — respond to user input mid-animation
- SVG transforms: apply on `<g>` wrapper with `transform-box: fill-box; transform-origin: center`
- Skeleton screens for content-heavy areas, spinners for focused actions, progress bars for multi-step processes

## 7. Charts & Data Visualization (LOW)

- Match chart type: trends → line, comparison → bar, composition → pie/donut, flow → sankey/funnel
- Sufficient contrast between data series; avoid relying on color alone
- Provide table alternative for accessibility

## Pattern Selection Guide

Choose the right UI pattern for the situation:

### Feedback & Notifications
| Situation | Pattern |
|-----------|---------|
| Action result (save, delete) | Toast notification |
| Form field error | Inline message next to the field; focus first error on submit |
| Page-level error or empty result | Inline alert banner or empty state illustration |
| Background process complete | Toast with optional action link |
| Long-running operation | Progress bar or skeleton with status text |

### Content Display
| Situation | Pattern |
|-----------|---------|
| Quick edit of a single field | Inline edit / click-to-edit |
| Create or edit a full record | Full page or slide-over panel |
| Confirm a destructive action | Confirmation dialog with explicit action name ("Delete project") |
| Supplementary details | Expandable section or collapsible panel |
| Auxiliary content (filters, details) | Side panel or sheet |

### Data & Lists
| Situation | Pattern |
|-----------|---------|
| <10 items, simple display | Simple list or card grid |
| 10–50 items with sorting/filtering | Table with column headers |
| >50 items | Virtualized list or paginated table |
| No data yet | Empty state with illustration and primary action CTA |
| Entity has no records | "No [items] yet. Create your first [item]." with action button |

### Navigation
| Situation | Pattern |
|-----------|---------|
| 2–5 top-level sections | Tab bar or horizontal tabs |
| >5 sections or nested hierarchy | Sidebar navigation |
| Settings or configuration groups | Vertical tabs or segmented sections |
| Step-by-step process | Stepper / wizard with progress indicator |

## Content & Copy

- Active voice: "Save changes" not "Changes will be saved"
- Title Case for headings and button labels
- Numerals for counts: "8 projects" not "eight projects"
- Specific button labels: "Save API Key" not "Continue" or "Submit"
- Error messages include the fix or next step, not just the problem
- Empty states include what the item is + how to create the first one