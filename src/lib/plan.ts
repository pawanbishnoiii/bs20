import { supabase } from "@/integrations/supabase/client";
import type { Session, Subject } from "@/lib/study";

/** One row of the automatic daily study plan. */
export type PlanItem = {
  id: string;
  plan_date: string;
  subject_id: string | null;
  chapter_name: string | null;
  session_kind: string;
  target_minutes: number;
  priority: number;
  source: string;
  pinned: boolean;
  completed_at: string | null;
};

export type PlanStatus = "complete" | "progress" | "pending";

/** Local (not UTC) yyyy-mm-dd, so plans line up with the student's day. */
export function localDateKey(d = new Date()) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(
    d.getDate(),
  ).padStart(2, "0")}`;
}

export async function fetchPlan(planDate = localDateKey()): Promise<PlanItem[]> {
  const { data, error } = await supabase
    .from("daily_study_plan_items")
    .select(
      "id, plan_date, subject_id, chapter_name, session_kind, target_minutes, priority, source, pinned, completed_at",
    )
    .eq("plan_date", planDate)
    .order("priority", { ascending: true });
  if (error) throw error;
  return (data ?? []) as PlanItem[];
}

/** Ask the database to (re)build the plan for a date and return the new rows. */
export async function generatePlan(planDate = localDateKey()): Promise<PlanItem[]> {
  const { error } = await supabase.rpc("refresh_my_study_plan", { p_plan_date: planDate });
  if (error) throw error;
  return fetchPlan(planDate);
}

export async function setPlanItemDone(id: string, done: boolean) {
  const { error } = await supabase
    .from("daily_study_plan_items")
    .update({ completed_at: done ? new Date().toISOString() : null })
    .eq("id", id);
  if (error) throw error;
}

const norm = (v: string | null | undefined) => (v ?? "").trim().toLowerCase();

/** Minutes already logged today for a plan row, matched by subject + chapter. */
export function planItemMinutes(item: PlanItem, sessions: Session[], since: Date) {
  return sessions
    .filter((s) => {
      if (s.is_running || !s.ended_at) return false;
      if (new Date(s.started_at) < since) return false;
      if (item.subject_id && s.subject_id !== item.subject_id) return false;
      if (item.chapter_name) {
        const target = norm(item.chapter_name);
        if (norm(s.chapter) !== target && norm(s.topic) !== target) return false;
      }
      return true;
    })
    .reduce((a, s) => a + (s.duration_minutes ?? 0), 0);
}

export function planItemStatus(item: PlanItem, minutes: number): PlanStatus {
  if (item.completed_at || (item.target_minutes > 0 && minutes >= item.target_minutes))
    return "complete";
  return minutes > 0 ? "progress" : "pending";
}

/** A recorded practice/test attempt, used for topic-wise accuracy. */
export type TestAttempt = {
  id: string;
  subject_id: string | null;
  chapter_id: string | null;
  scope: string;
  questions_total: number;
  questions_attempted: number;
  questions_correct: number;
  score: number | null;
  taken_at: string;
};

export async function fetchAttempts(sinceIso?: string): Promise<TestAttempt[]> {
  let q = supabase
    .from("test_attempts")
    .select(
      "id, subject_id, chapter_id, scope, questions_total, questions_attempted, questions_correct, score, taken_at",
    )
    .order("taken_at", { ascending: false });
  if (sinceIso) q = q.gte("taken_at", sinceIso);
  const { data, error } = await q;
  if (error) throw error;
  return (data ?? []) as TestAttempt[];
}

export type SubjectPerformance = {
  id: string;
  name: string;
  color: string;
  minutes: number;
  targetMinutes: number;
  pct: number;
  topicsTotal: number;
  topicsDone: number;
  attempted: number;
  correct: number;
  incorrect: number;
  accuracy: number;
};

/**
 * Real subject-wise performance: minutes vs target, chapters completed and
 * question accuracy from recorded attempts.
 */
export function subjectPerformance(
  subjects: Subject[],
  sessions: Session[],
  attempts: TestAttempt[],
  since: Date,
  targetScale = 1,
): SubjectPerformance[] {
  const done = new Map<string, Set<string>>();
  const mins = new Map<string, number>();

  for (const s of sessions) {
    if (s.is_running || !s.subject_id) continue;
    if (new Date(s.started_at) >= since)
      mins.set(s.subject_id, (mins.get(s.subject_id) ?? 0) + (s.duration_minutes ?? 0));
    const chapter = norm(s.chapter) || norm(s.topic);
    if (!chapter) continue;
    const set = done.get(s.subject_id) ?? new Set<string>();
    set.add(chapter);
    done.set(s.subject_id, set);
  }

  return subjects
    .map((subject) => {
      const rows = attempts.filter((a) => a.subject_id === subject.id);
      const attempted = rows.reduce((a, r) => a + (r.questions_attempted ?? 0), 0);
      const correct = rows.reduce((a, r) => a + (r.questions_correct ?? 0), 0);
      const minutes = mins.get(subject.id) ?? 0;
      const targetMinutes = Math.round(subject.weekly_target_hours * 60 * targetScale);
      const chapters = subject.chapters ?? [];
      const doneSet = done.get(subject.id) ?? new Set<string>();
      return {
        id: subject.id,
        name: subject.name,
        color: subject.color,
        minutes,
        targetMinutes,
        pct: targetMinutes > 0 ? Math.min(100, Math.round((minutes / targetMinutes) * 100)) : 0,
        topicsTotal: chapters.length,
        topicsDone: chapters.filter((c) => doneSet.has(norm(c))).length,
        attempted,
        correct,
        incorrect: Math.max(0, attempted - correct),
        accuracy: attempted > 0 ? Math.round((correct / attempted) * 100) : 0,
      };
    })
    .sort((a, b) => b.minutes - a.minutes);
}
