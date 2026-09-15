# Complete Today, Study, Timetable, targets, and theme upgrade

## Goal
Finish the requested experience without replacing existing data or working flows: show the supplied motion assets, make Today use the automatic syllabus plan and real performance metrics, expose that plan on Study and Timetable, add subject targets for daily/weekly/monthly work, and strengthen day/night presentation.

## Today
- Replace the old timetable-only “Your plan” section with the existing automatic `DailyPlanCard`.
- Place the supplied `hero.mp4` in the main Today focus panel, `loading.mp4` in the automatic-plan loading/empty state, and `showcase.mp4` in the analytics panel. Videos will autoplay muted, loop, play inline, use fixed responsive dimensions, and fall back cleanly for reduced-motion users.
- Upgrade subject performance to use the existing real session and test-attempt data: completed topics, total topics, attempted, correct, incorrect, accuracy/average percentage, study time, and target progress.
- Keep charts and progress live by adding plan items, chapter learning state, and test attempts to the existing realtime cache refresh map.

## Automatic syllabus plan and revision dates
- Keep the current additive 1/3/7/15/30-day revision engine and harden it rather than replacing it.
- Extend plan reads with subject/chapter identifiers, subject names, revision stage, and next-review date so cards can show exactly what to study and when review is due.
- Preserve manually completed and pinned plan items during regeneration; continue prioritizing due revision, then unread syllabus chapters, then subject fallback blocks.
- Add a safe “generate today” action that is idempotent and automatically runs when today has no plan.

## Study
- Add a “Today’s plan” area above recent sessions using the same live plan data, mascot artwork, status labels, progress bars, checkboxes, and revision dates.
- Let a plan item prefill activity, subject, chapter/topic, and planned duration in the existing study launcher; starting from a plan keeps the current session/timer behavior.
- On completion, refresh the plan and chapter-review state so progress and next revision update immediately.

## Timetable and targets
- Show real saved subjects and weekly timetable blocks as today; add a generated-plan agenda for the selected date with calculated start/end times and direct Start actions.
- Add an idempotent scheduler that allocates generated plan items into open timetable windows, avoids overlaps/duplicates, and preserves manually created blocks.
- Add an additive subject-target model for daily, weekly, and monthly goals covering minutes, topics, chapters, and practice questions. Existing target rows remain intact and continue working.
- Auto-create sensible subject targets from weekly subject hours and syllabus size only when missing; expose the resulting target progress on Timetable and Study.
- Add RLS and explicit grants for any new public table, scoped to the signed-in owner, with service-role access retained.

## Theme and motion
- Keep the existing header toggle, but upgrade semantic light/dark tokens for stronger pastel day colors, readable dark surfaces, chart contrast, borders, shadows, and focus states.
- Restore the app grid background, with a restrained warm grid by day and a brighter animated grid treatment at night; respect reduced-motion.
- Remove remaining hardcoded light-only colors from the touched Today, Study, Timetable, and plan components and use the shared theme tokens.

## Verification
- Apply the additive migration without resetting or deleting production data.
- Verify the plan generator returns syllabus-based items for the signed-in test account and inspect statuses plus revision dates.
- Run focused tests/type checks, then inspect Today, Study, and Timetable in authenticated desktop and mobile browser sessions.
- Confirm videos visibly play, plan checks persist, realtime data refreshes, timetable entries do not overlap, and both day/night modes remain readable.
