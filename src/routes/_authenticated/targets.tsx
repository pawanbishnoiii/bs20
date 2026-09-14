import { createFileRoute } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import {
  fetchSubjects,
  fetchTargets,
  createTarget,
  toggleTarget,
  deleteTarget,
  fetchSessions,
  fetchSettings,
  fmtHM,
  minutesInRange,
  startOfWeek,
  targetProgress,
} from "@/lib/study";
import { ProgressRing } from "@/components/motion/gsap-bits";
import { SubjectsManager } from "@/components/SubjectsManager";

const EIGHT_WEEKS = new Date(Date.now() - 8 * 7 * 864e5).toISOString();

export const Route = createFileRoute("/_authenticated/targets")({
  head: () => ({
    meta: [
      { title: "Targets — Chronodeck Study OS" },
      {
        name: "description",
        content: "Set daily and weekly study targets so the AI coach can measure your progress.",
      },
      { property: "og:title", content: "Targets — Chronodeck Study OS" },
      {
        property: "og:description",
        content: "Daily and weekly study goals with AI-tracked progress.",
      },
    ],
  }),
  component: TargetsPage,
});

const inputCls =
  "h-11 w-full rounded-xl border border-border bg-background px-3 text-sm outline-none focus:border-brand/60";

function TargetsPage() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);

  const targets = useQuery({ queryKey: ["targets"], queryFn: fetchTargets });
  const subjects = useQuery({ queryKey: ["subjects"], queryFn: fetchSubjects });
  const sessions = useQuery({ queryKey: ["sessions", "8w"], queryFn: () => fetchSessions(EIGHT_WEEKS) });
  const settings = useQuery({ queryKey: ["settings"], queryFn: fetchSettings });

  const weeklyGoal = settings.data?.weekly_goal_hours ?? 26;
  const weekMin = minutesInRange(sessions.data ?? [], startOfWeek());
  const weekPct = weeklyGoal > 0 ? Math.min(100, Math.round((weekMin / (weeklyGoal * 60)) * 100)) : 0;

  const createM = useMutation({
    mutationFn: createTarget,
    onSuccess: () => {
      setOpen(false);
      qc.invalidateQueries();
      toast.success("Target added.");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const toggleM = useMutation({
    mutationFn: ({ id, is_active }: { id: string; is_active: boolean }) => toggleTarget(id, is_active),
    onSuccess: () => qc.invalidateQueries(),
    onError: (e: Error) => toast.error(e.message),
  });

  const deleteM = useMutation({
    mutationFn: deleteTarget,
    onSuccess: () => {
      qc.invalidateQueries();
      toast.success("Target deleted.");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  return (
    <>
      <section className="px-4 pt-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold tracking-tight">Targets</h1>
            <p className="mt-1 text-xs text-muted-foreground">
              Daily and weekly goals the AI compares against real study time.
            </p>
          </div>
          <button
            onClick={() => setOpen(true)}
            className="h-10 shrink-0 rounded-xl bg-brand px-4 text-sm font-semibold whitespace-nowrap text-brand-foreground"
          >
            New target
          </button>
        </div>

        {/* Hero — weekly completion ring */}
        <div className="gradient-border mt-5 rounded-2xl p-6">
          <ProgressRing
            pct={weekPct}
            label="This week"
            sub={`${fmtHM(weekMin)} / ${fmtHM(weeklyGoal * 60)}`}
          />
        </div>
      </section>

      <section className="mt-5 px-4">
        <SubjectsManager />
      </section>

      <section className="mt-5 space-y-3 px-5">
        {(targets.data ?? []).length === 0 && (
          <div className="glass-panel p-6 text-center">
            <p className="text-sm text-muted-foreground">No targets yet.</p>
            <p className="mt-1 text-xs text-muted-foreground">Add your first goal to unlock AI insights.</p>
          </div>
        )}
        {(targets.data ?? []).map((t) => (
          <div key={t.id} className="glass-panel p-4">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <span
                    className={`size-2 rounded-full ${t.is_active ? "bg-brand" : "bg-muted-foreground"}`}
                  />
                  <h3 className={`text-sm font-semibold ${t.is_active ? "" : "text-muted-foreground"}`}>
                    {t.title}
                  </h3>
                </div>
                <p className="mt-1 font-mono text-[11px] text-muted-foreground">
                  {t.daily_hours}h daily · {t.weekly_hours}h weekly
                  {t.deadline ? ` · due ${new Date(t.deadline).toLocaleDateString()}` : ""}
                </p>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                <button
                  onClick={() => toggleM.mutate({ id: t.id, is_active: !t.is_active })}
                  className="rounded-lg border border-border px-2.5 py-1.5 text-[10px] font-medium text-muted-foreground hover:text-foreground"
                >
                  {t.is_active ? "Pause" : "Resume"}
                </button>
                <button
                  onClick={() => deleteM.mutate(t.id)}
                  className="text-[10px] text-muted-foreground hover:text-destructive"
                >
                  Delete
                </button>
              </div>
            </div>

            <TargetProgressBars target={t} sessions={sessions.data ?? []} />
          </div>
        ))}
      </section>

      {open && (
        <AddTargetSheet
          subjects={subjects.data ?? []}
          busy={createM.isPending}
          onClose={() => setOpen(false)}
          onAdd={(v) => createM.mutate(v)}
        />
      )}
    </>
  );
}

/** Live daily/weekly completion for one target, computed from real sessions. */
function TargetProgressBars({
  target,
  sessions,
}: {
  target: Parameters<typeof targetProgress>[0];
  sessions: Parameters<typeof targetProgress>[1];
}) {
  const p = targetProgress(target, sessions);
  const rows = [
    { label: "Today", pct: p.dailyPct, done: p.todayMinutes, goal: target.daily_hours * 60 },
    { label: "Week", pct: p.weeklyPct, done: p.weekMinutes, goal: target.weekly_hours * 60 },
  ];
  return (
    <div className="mt-3 space-y-2">
      {rows.map((r) => (
        <div key={r.label} className="grid grid-cols-[3rem_minmax(0,1fr)_auto] items-center gap-2">
          <span className="text-[10px] tracking-wide text-muted-foreground uppercase">{r.label}</span>
          <span className="h-1.5 overflow-hidden rounded-full bg-muted">
            <span
              className="gradient-bar block h-full rounded-full transition-[width] duration-700 ease-out"
              style={{ width: `${r.pct}%` }}
            />
          </span>
          <span className="num shrink-0 text-[10px] text-muted-foreground">
            {fmtHM(r.done)} / {fmtHM(r.goal)}
          </span>
        </div>
      ))}
    </div>
  );
}

function AddTargetSheet({
  subjects,
  busy,
  onClose,
  onAdd,
}: {
  subjects: { id: string; name: string }[];
  busy: boolean;
  onClose: () => void;
  onAdd: (v: {
    title: string;
    subject_id: string | null;
    daily_hours: number;
    weekly_hours: number;
    deadline: string | null;
  }) => void;
}) {
  const [subjectId, setSubjectId] = useState(subjects[0]?.id ?? "");
  const [custom, setCustom] = useState("");
  const [daily, setDaily] = useState("1");
  const [weekly, setWeekly] = useState("7");
  const [deadline, setDeadline] = useState("");
  const title = subjectId ? subjects.find((s) => s.id === subjectId)?.name : custom;
  const dailyNumber = Number(daily);
  const weeklyNumber = Number(weekly);
  const validation = !Number.isFinite(dailyNumber) || dailyNumber < 0 || dailyNumber > 24
    ? "Daily hours must be between 0 and 24."
    : !Number.isFinite(weeklyNumber) || weeklyNumber < 0 || weeklyNumber > 168
      ? "Weekly hours must be between 0 and 168."
      : !title?.trim() ? "Choose a subject or enter a target title." : null;
  return (
    <div className="fixed inset-0 z-[80] flex items-end bg-foreground/25 backdrop-blur-sm">
      <div className="max-h-[88svh] w-full overflow-y-auto rounded-t-3xl border-t border-border bg-panel p-5 pb-[calc(2.5rem+env(safe-area-inset-bottom))]">
        <h3 className="text-base font-semibold tracking-tight">New target</h3>
        <div className="mt-4 space-y-3">
          <select value={subjectId} onChange={(e) => setSubjectId(e.target.value)} className={inputCls}>
            <option value="">Custom title</option>
            {subjects.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
          {!subjectId && (
            <input
              className={inputCls}
              placeholder="target title"
              value={custom}
              onChange={(e) => setCustom(e.target.value)}
            />
          )}
          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="mb-1 block font-mono text-[10px] text-muted-foreground uppercase">
                Daily hours
              </label>
              <input
                type="number"
                min={0}
                step={0.5}
                value={daily}
                onChange={(e) => setDaily(e.target.value)}
                className={inputCls}
              />
            </div>
            <div>
              <label className="mb-1 block font-mono text-[10px] text-muted-foreground uppercase">
                Weekly hours
              </label>
              <input
                type="number"
                min={0}
                step={0.5}
                value={weekly}
                onChange={(e) => setWeekly(e.target.value)}
                className={inputCls}
              />
            </div>
          </div>
          <div>
            <label className="mb-1 block font-mono text-[10px] text-muted-foreground uppercase">
              Deadline (optional)
            </label>
            <input type="date" value={deadline} onChange={(e) => setDeadline(e.target.value)} className={inputCls} />
          </div>
          <div className="flex gap-2 pt-1">
            {validation ? <p role="alert" className="col-span-2 text-xs text-destructive">{validation}</p> : null}
            <button onClick={onClose} className="h-11 flex-1 rounded-xl border border-border text-sm">
              Cancel
            </button>
            <button
              disabled={busy || Boolean(validation)}
              onClick={() =>
                onAdd({
                  title: title || custom || "Study goal",
                  subject_id: subjectId || null,
                  daily_hours: Number(daily) || 0,
                  weekly_hours: Number(weekly) || 0,
                  deadline: deadline || null,
                })
              }
              className="h-11 flex-[2] rounded-xl bg-brand text-sm font-semibold text-brand-foreground disabled:opacity-60"
            >
              Save target
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
