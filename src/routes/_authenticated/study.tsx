import { createFileRoute, useNavigate, useSearch } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { motion, AnimatePresence } from "framer-motion";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import { Check, History } from "lucide-react";
import {
  currentBlock,
  fetchBlocks,
  fetchRunningSession,
  fetchSessions,
  fetchSubjects,
  fmtHM,
  localTimeToIsoToday,
  relativeTime,
  startSession,
  startOfToday,
} from "@/lib/study";
import { SubjectsManager } from "@/components/SubjectsManager";
import { LottiePlayer } from "@/components/ui/lottie-player";
import appointmentAnim from "@/assets/appointment-booking.json.asset.json";

const SESSION_KINDS = [
  { k: "reading", l: "Reading", d: "Books & notes", emoji: "\u{1F4D6}" },
  { k: "class", l: "Online class", d: "Live / recorded", emoji: "\u{1F3A7}" },
  { k: "revision", l: "Revision", d: "Recall & re-read", emoji: "\u{1F501}" },
  { k: "practice", l: "Practice", d: "Papers & problems", emoji: "\u{270F}\u{FE0F}" },
] as const;


export const Route = createFileRoute("/_authenticated/study")({
  head: () => ({
    meta: [
      { title: "Study Mode — Chronodeck" },
      {
        name: "description",
        content: "Pick a subject, choose a category and launch the distraction-free focus timer.",
      },
      { property: "og:title", content: "Study Mode — Chronodeck" },
      {
        property: "og:description",
        content: "Set up your study session and start the clean full-screen focus timer.",
      },
    ],
  }),
  component: StudySetupPage,
});

function StudySetupPage() {
  const qc = useQueryClient();
  const navigate = useNavigate();
  const search = useSearch({ from: "/_authenticated/study" }) as { block?: string };
  const [form, setForm] = useState({
    subject_id: "",
    subject_name: "",
    topic: "",
    chapter: "",
    kind: "reading",
    planned_end_at: "",
  });
  const [subjectSheet, setSubjectSheet] = useState(false);

  const running = useQuery({ queryKey: ["running"], queryFn: fetchRunningSession });
  const subjects = useQuery({ queryKey: ["subjects"], queryFn: fetchSubjects });
  const blocks = useQuery({ queryKey: ["blocks"], queryFn: fetchBlocks });
  const recent = useQuery({
    queryKey: ["sessions", "study-recent"],
    queryFn: () => fetchSessions(new Date(startOfToday().getTime() - 13 * 864e5).toISOString()),
  });
  const activeSubject = (subjects.data ?? []).find((s) => s.id === form.subject_id);


  // The timer lives on its own page — a live session always belongs there.
  useEffect(() => {
    if (running.data) navigate({ to: "/timer" });
  }, [running.data, navigate]);

  /** Auto-fill subject + kind from the timetable block covering now, or the one picked by URL. */
  useEffect(() => {
    if (running.data || form.subject_id || form.subject_name || !blocks.data) return;
    const selected = search.block ? blocks.data.find((b) => b.id === search.block) : null;
    const b = selected || currentBlock(blocks.data);
    if (b) {
      setForm((f) => ({
        ...f,
        subject_id: b.subject_id ?? "",
        subject_name: b.subject_id ? "" : b.title,
        kind: b.kind === "class" ? "class" : "reading",
        topic: f.topic || b.title,
        planned_end_at: b.end_time,
      }));
    }
  }, [blocks.data, running.data, form.subject_id, form.subject_name, search.block]);

  const start = useMutation({
    mutationFn: async () => {
      const subj = (subjects.data ?? []).find((s) => s.id === form.subject_id);
      const plannedEnd = form.planned_end_at ? localTimeToIsoToday(form.planned_end_at) : null;
      return startSession({
        subject_id: subj?.id ?? null,
        subject_name: subj?.name ?? (form.subject_name.trim() || "Study"),
        topic: form.topic.trim() || null,
        chapter: form.chapter.trim() || null,
        kind: form.kind,
        planned_end_at: plannedEnd,
      });
    },
    onSuccess: (session) => {
      // Seed the cache before navigating so the timer page opens with the live
      // session already in hand instead of bouncing back here.
      qc.setQueryData(["running"], session);
      void qc.invalidateQueries({ queryKey: ["sessions", "8w"] });
      void qc.invalidateQueries({ queryKey: ["sessions", "study-recent"] });
      toast.success("Study mode on");

      navigate({ to: "/timer" });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  return (
    <div className="flex w-full flex-col items-center px-4 pt-3 pb-8 text-foreground">
      <motion.div
        initial={{ opacity: 0, y: 18, filter: "blur(6px)" }}
        animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
        transition={{ duration: 0.45, ease: [0.16, 1, 0.3, 1] }}
        className="w-full max-w-md"
      >
        <div className="pop-sheet p-5">
          <div className="flex items-center gap-3">
            <div className="min-w-0 flex-1">
              <p className="eyebrow">study mode</p>
              <h1 className="mt-2 text-2xl font-bold">Set up your session</h1>
              <p className="mt-1 text-xs text-muted-foreground">Subject, category aur focus time choose karo.</p>
            </div>
            <LottiePlayer src={appointmentAnim.url} className="size-24 shrink-0" />
          </div>

          <div className="mt-5 flex items-center justify-between">
            <label className="eyebrow">subject</label>
            <button
              type="button"
              onClick={() => setSubjectSheet(true)}
              className="rounded-full border border-border px-3 py-1.5 text-[11px] font-bold text-foreground"
            >
              + Add subject
            </button>
          </div>
          <div className="mt-2 flex flex-wrap gap-2">
            {subjects.isLoading ? (
              <div className="flex gap-2">
                {[0, 1, 2].map((i) => (
                  <span key={i} className="h-9 w-24 animate-pulse rounded-full bg-muted" />
                ))}
              </div>
            ) : null}
            {!subjects.isLoading && (subjects.data ?? []).length === 0 ? (
              <p className="text-xs text-muted-foreground">Koi subject nahi — pehle ek subject add karo.</p>
            ) : null}
            {(subjects.data ?? []).map((x) => {
              const on = form.subject_id === x.id;
              return (
                <motion.button
                  key={x.id}
                  type="button"
                  whileTap={{ scale: 0.95 }}
                  onClick={() =>
                    setForm({ ...form, subject_id: x.id, subject_name: x.name, chapter: "" })
                  }
                  aria-pressed={on}
                  className={`flex items-center gap-2 rounded-full border-2 px-3.5 py-2 text-xs font-bold transition ${
                    on
                      ? "border-transparent bg-primary text-primary-foreground"
                      : "border-border bg-secondary/60 text-muted-foreground"
                  }`}
                >
                  <span className="size-2.5 rounded-full" style={{ background: x.color }} />
                  {x.name}
                </motion.button>
              );
            })}
          </div>

          {activeSubject ? (
            <div className="mt-4">
              <label className="eyebrow">chapter</label>
              {activeSubject.chapters.length === 0 ? (
                <p className="mt-2 text-xs text-muted-foreground">
                  Is subject me chapters nahi — “+ Add subject” se chapters add karo.
                </p>
              ) : (
                <div className="mt-2 flex flex-wrap gap-2">
                  {activeSubject.chapters.map((c) => {
                    const on = form.chapter === c;
                    return (
                      <motion.button
                        key={c}
                        type="button"
                        whileTap={{ scale: 0.95 }}
                        onClick={() => setForm({ ...form, chapter: on ? "" : c, topic: form.topic || c })}
                        aria-pressed={on}
                        className={`flex items-center gap-1.5 rounded-full border-2 px-3 py-1.5 text-[11px] font-bold transition ${
                          on
                            ? "border-transparent bg-foreground text-background"
                            : "border-border bg-secondary/50 text-muted-foreground"
                        }`}
                      >
                        {on ? <Check className="size-3.5" /> : null}
                        {c}
                      </motion.button>
                    );
                  })}
                </div>
              )}
            </div>
          ) : null}

          <input
            value={form.topic}
            onChange={(e) => setForm({ ...form, topic: e.target.value })}
            placeholder="Topic / notes"
            className="mt-3 h-12 w-full rounded-full border-2 border-border bg-secondary/50 px-4 text-sm text-foreground placeholder:text-muted-foreground"
          />


          <label className="eyebrow mt-5 block">category</label>
          <div className="mt-2 grid grid-cols-2 gap-2">
            {SESSION_KINDS.map((o) => {
              const on = form.kind === o.k;
              return (
                <button
                  key={o.k}
                  onClick={() => setForm({ ...form, kind: o.k })}
                  aria-pressed={on}
                  className={`flex h-[78px] flex-col items-start justify-center gap-1 rounded-[24px] border px-3.5 text-left transition-all duration-200 active:scale-[0.98] ${
                    on
                      ? "border-transparent bg-primary/15 text-foreground shadow-[0_0_0_1.5px_var(--primary)]"
                      : "border-border bg-secondary/40 text-muted-foreground"
                  }`}
                >
                  <span className="text-lg leading-none">{o.emoji}</span>
                  <span className="text-sm font-semibold">{o.l}</span>
                  <span className="text-[10px] text-muted-foreground">{o.d}</span>
                </button>
              );
            })}
          </div>

          <motion.button
            whileTap={{ scale: 0.96 }}
            onClick={() => start.mutate()}
            disabled={start.isPending}
            className="btn-pop mt-5 w-full disabled:opacity-60"
          >
            {start.isPending ? "Starting…" : "Start timer"}
          </motion.button>
          <button onClick={() => navigate({ to: "/today" })} className="btn-ghost-pop mt-2 w-full">
            Back to home
          </button>
        </div>

        {/* Session history — what got recorded from this page */}
        <div className="pop-sheet mt-4 p-5">
          <div className="flex items-center gap-2">
            <span className="grid size-9 place-items-center rounded-2xl bg-primary/12 text-primary">
              <History className="size-4.5" />
            </span>
            <h2 className="text-base font-extrabold tracking-tight">Session history</h2>
            <span className="ml-auto text-[11px] font-semibold text-muted-foreground">last 14 days</span>
          </div>

          {recent.isLoading ? (
            <div className="mt-4 grid gap-2">
              {[0, 1, 2].map((i) => (
                <span key={i} className="h-14 animate-pulse rounded-2xl bg-muted" />
              ))}
            </div>
          ) : (recent.data ?? []).length === 0 ? (
            <p className="mt-4 text-xs text-muted-foreground">
              Abhi koi session nahi — upar se ek session start karo.
            </p>
          ) : (
            <ul className="mt-4 grid gap-2">
              {(recent.data ?? []).slice(0, 12).map((s) => (
                <li
                  key={s.id}
                  className="flex items-center gap-3 rounded-2xl border-2 border-border bg-secondary/40 px-3.5 py-3"
                >
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-bold">
                      {s.subject_name || "Study"}
                      {s.chapter ? <span className="text-muted-foreground"> · {s.chapter}</span> : null}
                    </span>
                    <span className="block truncate text-[11px] text-muted-foreground">
                      {s.kind} · {relativeTime(s.started_at)}
                      {s.topic ? ` · ${s.topic}` : ""}
                    </span>
                  </span>
                  <span className="num shrink-0 rounded-full bg-background px-3 py-1 text-[11px] font-bold">
                    {s.is_running ? "live" : fmtHM(s.duration_minutes ?? 0)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </motion.div>


      <AnimatePresence>
        {subjectSheet ? (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[60] flex items-end bg-black/60 backdrop-blur-sm"
            onClick={() => setSubjectSheet(false)}
          >
            <motion.div
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              transition={{ type: "spring", stiffness: 420, damping: 38, mass: 0.9 }}
              drag="y"
              dragConstraints={{ top: 0, bottom: 0 }}
              dragElastic={{ top: 0, bottom: 0.4 }}
              onDragEnd={(_, info) => {
                if (info.offset.y > 120 || info.velocity.y > 700) setSubjectSheet(false);
              }}
              onClick={(e) => e.stopPropagation()}
              className="max-h-[85vh] w-full touch-pan-y overflow-y-auto rounded-t-[40px] bg-background p-5 pb-[calc(1.5rem+env(safe-area-inset-bottom))] text-foreground shadow-[0_-24px_60px_-30px_rgb(0_0_0_/_0.6)]"
            >
              <div className="mx-auto mb-4 h-1.5 w-12 rounded-full bg-border" />

              <SubjectsManager
                selectedId={form.subject_id}
                onSelect={(s) => {
                  setForm((f) => ({ ...f, subject_id: s.id, subject_name: s.name }));
                  setSubjectSheet(false);
                }}
              />
              <button
                type="button"
                onClick={() => setSubjectSheet(false)}
                className="mt-4 h-12 w-full rounded-full border border-border text-sm font-semibold"
              >
                Done
              </button>
            </motion.div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  );
}
