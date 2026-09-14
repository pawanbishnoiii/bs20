# Chronodeck seven-page visual redesign and history restore

## Goal
Rebuild the existing `/auth`, `/welcome`, `/today`, `/study`, `/timetable`, `/targets`, and `/profile` experiences around the supplied pastel education references, while preserving all current queries, mutations, authentication flows, and study data behavior. `/study` will receive the deepest interaction and layout upgrade.

## Visual foundation and shared UI
- Consolidate the warm-white, near-black, lavender, blue, pink, yellow, mint, peach, border, focus, elevation, and activity-color tokens in the global design system; correct the activity mapping to Reading=yellow, Revision=lavender, Online Class=blue, Test/Practice=mint.
- Add focused reusable pieces for page headings, illustrated panels, activity and subject cards, segmented controls, week strips, timeline blocks, compact progress, empty states, form sections, responsive sheets, and sticky actions.
- Replace broad route-level CSS overrides with component-scoped styling so one page cannot accidentally restyle another.
- Update the shared shell: mobile safe-area dock, tablet transition, and a real desktop sidebar at roughly 220–240px. Keep the account menu/profile entry and correct route highlighting.
- Replace the large floating notification prompt with a compact dismissible inline invitation that requests permission only after an explicit click.
- Standardize readable labels, 44px controls, keyboard focus, loading/error/success/disabled states, long-name handling, and reduced-motion behavior.

## Original illustration family
- Generate a coherent soft clay-like 3D asset set without text: authentication student, welcome learning-path student, four activity objects/scenes, compact study hero, and small schedule/target empty states.
- Integrate every generated asset with reserved dimensions, meaningful alt text where informative, and lazy loading for noncritical artwork.
- Reuse existing Chronodeck branding and owl only where it remains visually consistent.

## Page redesigns

### `/auth`
- Build a compact periwinkle illustrated top panel and overlapping white form on mobile; use a balanced illustration/form split on desktop.
- Preserve Google, One Tap, email sign-in/sign-up, confirmation, forgot-password, validation, autofill, password visibility, and redirect behavior.
- Keep form dimensions stable while switching modes and ensure the mobile keyboard does not hide actions.

### `/welcome`
- Recompose navigation, editorial hero, layered HTML study previews, four activity cards, Plan → Focus → Review, schedule preview, dark progress section, About, FAQ, final CTA, and footer.
- Keep preview numbers clearly identified as demonstration data; add restrained GSAP scroll reveals only on this page.

### `/today`
- Reorganize around greeting/date/notifications and one illustrated focus card with goal, progress, next action, and Start/Resume.
- Add compact day/week/month summaries, seven-day strip, today/next-day agenda, real suggestions when present, recent sessions, dark weekly analytics, subject progress, and targets.
- Preserve reading habits, streak, breaks, hourly/monthly analytics, planner ordering, target editing, and current session behavior; move secondary detail into scannable or expandable groups.

### `/study` — primary upgrade
- Desktop: spacious two-column launcher with a broad selection workspace and sticky session summary. Mobile: progressive single-column flow and safe-area sticky Start action.
- Add four clear illustrated activity cards; searchable subject cards; chapter search/selection with a mobile sheet; optional subtopic selection when normalized records exist; and settings for topic/notes/planned duration/timetable prefill.
- Keep whole-chapter sessions valid. Changing subject clears incompatible chapter/subtopic state and shows field-level validation.
- Preserve current active-session redirect and creation flow, then navigate to `/timer`; retain recent sessions and suggestions below the launcher.
- Restyle subject creation, chapter editing, and all related sheets without changing their working data handlers.

### `/timetable`
- Add concise week controls, Today action, List/Calendar segmented control, scroll-safe date strip, mobile timeline agenda, and desktop weekly calendar with selected-day details.
- Preserve block ordering, keyboard move controls, Start, add, and delete behavior; restyle editing as a responsive sheet and add a useful illustrated empty state.

### `/targets`
- Replace the oversized ring with a compact overview of actual time, goal, remaining work, and primary action.
- Separate targets and subject management clearly; use pastel target cards with status, deadline, time progress, expandable chapter coverage, edit/pause/delete actions, and confirmation for destructive actions.
- Flag imported values such as `40h daily` as invalid and request correction without silently changing stored data. Never infer chapter mastery from elapsed time.

### `/profile`
- Build a pastel identity panel with avatar/initials, role badge, real summary, compact stats, and a secondary admin action.
- Group avatar, personal details, study preferences, notifications, and account settings with visible labels, inline validation, and clear dirty/saving/saved feedback.
- Preserve profile, avatar upload/preset, push, role, and save behavior; show achievements only from real records.

## Admin account and uploaded history
- First correct/rebind the project’s stale frontend backend connection so the preview and database tools target this remixed project’s Lovable Cloud instance.
- Create or locate `a@a.a`, assign the admin role through server-verified role data, and keep the supplied password private.
- Parse the uploaded CSV as its actual shape: one JSON export containing the source user and related records.
- Import idempotently into the new account by remapping every source `user_id`/profile identity to the new account, preserving stable record IDs where conflict-free, and respecting parent/child order and foreign keys.
- Compare before writing, avoid duplicates on reruns, preserve timestamps and history, and report exact imported counts. No original project/database is touched.

## Verification
- Run the project’s lint and production build workflows and resolve introduced errors.
- Inspect all seven routes at 320px mobile, tablet, and wide desktop. Check overflow, text wrapping, sidebar/dock behavior, sheets, dialogs, focus states, and reduced motion.
- Test sign-in, subject/chapter selection, session launch, timetable add/reorder/start/delete, target create/edit/pause/delete, profile save/avatar/push, and notification dismissal.
- Verify the imported admin account’s subject/session/target/history counts and cross-user ownership after restore.

## Scope boundary
- This pass redesigns the seven requested pages and their supporting UI states. Existing timer internals, planner algorithms, database schema, and unrelated admin page designs remain unchanged unless a small compatibility fix is required to keep these flows working.
