import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AnimatePresence, motion } from "framer-motion";
import { BookOpen, Check, Newspaper, Settings2, Undo2 } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import {
  DEFAULT_READING_GOALS,
  READING_TASKS,
  fetchReadingGoals,
  fetchReadingLogs,
  logReading,
  readingStatus,
  saveReadingGoals,
  undoReading,
  type ReadingKind,
} from "@/lib/study";

/**
 * Compulsory reading, treated exactly like a subject: it carries its own daily
 * newspaper target and monthly magazine target, minutes add up through the day,
 * and a seven-day dot row keeps the streak visible.
 */
export function ReadingHabitCard() {
  const qc = useQueryClient();
  const [editing, setEditing] = useState(false);

  const logs = useQuery({ queryKey: ["reading-logs"], queryFn: fetchReadingLogs });
  const goalsQ = useQuery({ queryKey: ["reading-goals"], queryFn: fetchReadingGoals });
  const goals = goalsQ.data ?? DEFAULT_READING_GOALS;
  const status = readingStatus(logs.data ?? [], goals);

  const [daily, setDaily] = useState("");
  const [monthly, setMonthly] = useState("");

  const refresh = () => {
    void qc.invalidateQueries({ queryKey: ["reading-logs"] });
    void qc.invalidateQueries({ queryKey: ["reading-goals"] });
  };

  const addM = useMutation({
    mutationFn: ({ kind, minutes }: { kind: ReadingKind; minutes: number }) => logReading(kind, minutes),
    onSuccess: (_d, v) => {
      refresh();
      toast.success(`+${v.minutes} min added`);
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const undoM = useMutation({
    mutationFn: (kind: ReadingKind) => undoReading(kind),
    onSuccess: () => {
      refresh();
      toast.success("Entry hata di");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const goalM = useMutation({
    mutationFn: () =>
      saveReadingGoals({
        newspaper_daily_minutes: Math.max(1, Math.min(600, Number(daily) || goals.newspaper_daily_minutes)),
        magazine_monthly_minutes: Math.max(1, Math.min(6000, Number(monthly) || goals.magazine_monthly_minutes)),
      }),
    onSuccess: () => {
      setEditing(false);
      refresh();
      toast.success("Reading target updated");
    },
    onError: (e: Error) => toast.error(e.message),
  });

  return (
    <section className="rounded-[28px] border-2 border-foreground/10 bg-panel p-5 shadow-[0_18px_40px_-32px_rgb(0_0_0_/_0.45)]">
      <div className="flex items-center gap-3">
        <span className="grid size-10 place-items-center rounded-2xl bg-[var(--pop-mustard,theme(colors.amber.200))] text-[var(--pop-ink)]">
          <Newspaper className="size-5" />
        </span>
        <div className="min-w-0">
          <h2 className="text-base font-extrabold tracking-tight">Compulsory reading</h2>
          <p className="text-[11px] text-muted-foreground">Roz newspaper, mahine me ek magazine.</p>
        </div>
        <div className="ml-auto flex shrink-0 items-center gap-1.5">
          <span className="rounded-full bg-primary/12 px-3 py-1 text-[11px] font-bold text-primary">
            {status.newspaperStreak}d streak
          </span>
          <button
            type="button"
            aria-label="Edit reading targets"
            onClick={() => {
              setDaily(String(goals.newspaper_daily_minutes));
              setMonthly(String(goals.magazine_monthly_minutes));
              setEditing((v) => !v);
            }}
            className="grid size-8 place-items-center rounded-full border-2 border-border text-muted-foreground"
          >
            <Settings2 className="size-4" />
          </button>
        </div>
      </div>

      <AnimatePresence initial={false}>
        {editing ? (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.26, ease: [0.22, 1, 0.36, 1] }}
            className="overflow-hidden"
          >
            <div className="mt-4 grid gap-3 rounded-2xl border-2 border-border bg-background p-4">
              <label className="block text-[11px] font-bold text-muted-foreground">
                Newspaper — daily minutes
                <input
                  type="number"
                  min={1}
                  max={600}
                  value={daily}
                  onChange={(e) => setDaily(e.target.value)}
                  className="mt-1 h-11 w-full rounded-xl border-2 border-border bg-panel px-3 text-sm font-semibold text-foreground"
                />
              </label>
              <label className="block text-[11px] font-bold text-muted-foreground">
                Magazine — monthly minutes
                <input
                  type="number"
                  min={1}
                  max={6000}
                  value={monthly}
                  onChange={(e) => setMonthly(e.target.value)}
                  className="mt-1 h-11 w-full rounded-xl border-2 border-border bg-panel px-3 text-sm font-semibold text-foreground"
                />
              </label>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setEditing(false)}
                  className="h-11 flex-1 rounded-full border-2 border-border text-xs font-bold"
                >
                  Cancel
                </button>
                <motion.button
                  type="button"
                  whileTap={{ scale: 0.96 }}
                  disabled={goalM.isPending}
                  onClick={() => goalM.mutate()}
                  className="h-11 flex-[2] rounded-full bg-foreground text-xs font-bold text-background disabled:opacity-60"
                >
                  {goalM.isPending ? "Saving…" : "Save target"}
                </motion.button>
              </div>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>

      {/* seven-day newspaper dots */}
      <div className="mt-4 flex items-center justify-between gap-1">
        {status.week.map((d) => (
          <div key={d.key} className="flex flex-1 flex-col items-center gap-1.5">
            <motion.span
              layout
              title={`${d.minutes} min`}
              className={`grid size-8 place-items-center rounded-full border-2 text-[10px] font-bold ${
                d.done
                  ? "border-transparent bg-primary text-primary-foreground"
                  : d.today
                    ? "border-primary/60 text-primary"
                    : "border-border text-muted-foreground"
              }`}
            >
              {d.done ? <Check className="size-4" /> : d.label}
            </motion.span>
            <span className="text-[9px] font-semibold tracking-wide text-muted-foreground uppercase">
              {d.today ? "today" : d.label}
            </span>
          </div>
        ))}
      </div>

      <div className="mt-4 grid gap-2.5">
        {READING_TASKS.map((t) => {
          const isPaper = t.kind === "newspaper";
          const done = isPaper ? status.newspaperToday : status.magazineThisMonth;
          const minutes = isPaper ? status.newspaperTodayMinutes : status.magazineMinutes;
          const goal = isPaper ? goals.newspaper_daily_minutes : goals.magazine_monthly_minutes;
          const pct = isPaper ? status.newspaperPct : status.magazinePct;
          const hit = pct >= 100;
          return (
            <div
              key={t.kind}
              className={`rounded-2xl border-2 px-4 py-3 transition-colors ${
                hit ? "border-transparent bg-primary/12" : "border-border bg-secondary/40"
              }`}
            >
              <div className="flex items-center gap-3">
                <span className="text-xl leading-none">{t.emoji}</span>
                <span className="min-w-0 flex-1">
                  <span className="block text-sm font-bold">{t.label}</span>
                  <span className="num block text-[11px] text-muted-foreground">
                    {minutes} / {goal} min {isPaper ? "aaj" : "is mahine"}
                  </span>
                </span>
                <span
                  className={`grid size-8 shrink-0 place-items-center rounded-full border-2 ${
                    hit ? "border-transparent bg-primary text-primary-foreground" : "border-border"
                  }`}
                >
                  {hit ? <Check className="size-4" /> : <BookOpen className="size-4 opacity-50" />}
                </span>
              </div>

              <div className="mt-2.5 h-2 overflow-hidden rounded-full bg-background">
                <motion.span
                  className="block h-full rounded-full bg-primary"
                  initial={false}
                  animate={{ width: `${pct}%` }}
                  transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
                />
              </div>

              <div className="mt-2.5 flex flex-wrap items-center gap-1.5">
                {t.steps.map((m) => (
                  <motion.button
                    key={m}
                    type="button"
                    whileTap={{ scale: 0.94 }}
                    disabled={addM.isPending}
                    onClick={() => addM.mutate({ kind: t.kind, minutes: m })}
                    className="rounded-full border-2 border-border bg-background px-3 py-1 text-[11px] font-bold disabled:opacity-60"
                  >
                    +{m}m
                  </motion.button>
                ))}
                {done ? (
                  <button
                    type="button"
                    disabled={undoM.isPending}
                    onClick={() => undoM.mutate(t.kind)}
                    className="ml-auto flex items-center gap-1 text-[11px] font-bold text-muted-foreground hover:text-destructive disabled:opacity-60"
                  >
                    <Undo2 className="size-3.5" /> Unmark
                  </button>
                ) : (
                  <motion.button
                    type="button"
                    whileTap={{ scale: 0.94 }}
                    disabled={addM.isPending}
                    onClick={() => addM.mutate({ kind: t.kind, minutes: goal })}
                    className="ml-auto rounded-full bg-foreground px-3 py-1 text-[11px] font-bold text-background disabled:opacity-60"
                  >
                    Mark done
                  </motion.button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
