# Chronodeck UI polish and mobile app experience

## What will change

### Visual assets and activity experience
- Add the uploaded `study_time.png` as a real Study-page visual without removing existing project images.
- Upload and use `27832-52591-animojis-2.riv` for animated activity moments in Study and plan surfaces.
- Keep the existing four transparent activity icons, but restyle their containers with cohesive glossy clay depth, highlights, and cleaner selected states.
- Generate a small matching set of glossy clay illustration accents only where the existing and uploaded assets do not cover the UI.

### Today and analytics
- Remove the Super Woman animation from the Analytics section.
- Replace the current compact Today summary with reusable animated status cards based on the supplied `ChartDataItem` component pattern.
- Feed those cards real Today/week/month study data, with animated values and bars.
- Polish the Analytics controls, charts, subject-performance rows, spacing, and mobile stacking while preserving existing queries and actions.

### Study pace redesign
- Replace “average to finish a chapter” with personal pace insights that do not compare unlike chapters.
- Show useful metrics such as completed chapter count, total focused time, average reading sitting, and average revision sitting.
- Explain plan time as a minimum focus commitment rather than an estimate of chapter completion.
- Improve the Study launcher’s activity tiles, summary panel, plan rows, touch targets, and phone layout.

### Day/night polish
- Rebuild the day/night switch so the sun and moon are perfectly centered in fixed-size positions.
- Strengthen the light palette with cleaner contrast and richer pastel accents.
- Refine dark surfaces, grid visibility, card elevation, and glossy highlights without reducing readability.

### Phone-first app feel
- Tighten page spacing and card density on small screens while keeping 44px+ touch targets.
- Make activity cards, status cards, plan items, sticky controls, and bottom navigation feel like a native mobile app.
- Preserve desktop layouts and installable-app behavior.

## Technical details
- Add a reusable animated stats-card component using semantic design tokens and the supplied Framer Motion pattern.
- Extend the Rive wrapper only as needed for responsive playback and graceful fallback.
- Store uploaded binary assets through the project asset flow and import their pointer files.
- Keep all existing backend data, plan generation, timers, targets, and completion behavior unchanged.
- Update route metadata only if a touched content route is missing required tags.

## Verification
- Run the project lint and production build checks.
- Inspect Today and Study at desktop and mobile widths in both light and dark modes.
- Confirm the theme control alignment, Rive playback, uploaded image rendering, Analytics without Super Woman, and no horizontal overflow.
