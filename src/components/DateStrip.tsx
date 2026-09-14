import { useMemo, useState } from "react";

/** Real 7-day calendar strip with today highlighted and a selectable date. */
export function DateStrip({
  onSelect,
  className,
}: {
  onSelect?: (date: Date) => void;
  className?: string;
}) {
  const today = useMemo(() => new Date(), []);
  const [selected, setSelected] = useState(() => today.toDateString());

  const days = useMemo(() => {
    const start = new Date(today);
    start.setDate(start.getDate() - start.getDay() + 1); // Monday
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(start);
      d.setDate(start.getDate() + i);
      return d;
    });
  }, [today]);

  return (
    <section
      className={`rounded-[28px] border border-border bg-panel p-4 shadow-[0_18px_44px_-32px_rgb(20_21_26/0.5)] ${className ?? ""}`}
      aria-label="Week calendar"
    >
      <div className="flex items-baseline justify-between gap-3">
        <p className="text-base font-extrabold tracking-tight">
          {today.toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" })}
        </p>
        <p className="text-xs text-muted-foreground">
          {today.toLocaleDateString(undefined, { year: "numeric" })}
        </p>
      </div>
      <ol className="mt-3 grid grid-cols-7 gap-1.5">
        {days.map((d) => {
          const isToday = d.toDateString() === today.toDateString();
          const isSelected = d.toDateString() === selected;
          return (
            <li key={d.toISOString()}>
              <button
                type="button"
                aria-current={isToday ? "date" : undefined}
                aria-pressed={isSelected}
                onClick={() => {
                  setSelected(d.toDateString());
                  onSelect?.(d);
                }}
                className={`flex w-full flex-col items-center gap-1 rounded-2xl px-1 py-2.5 text-sm transition ${
                  isSelected
                    ? "bg-foreground text-background"
                    : isToday
                      ? "bg-accent text-accent-foreground"
                      : "bg-secondary/60 text-muted-foreground hover:text-foreground"
                }`}
              >
                <span className="text-[11px] font-semibold uppercase">
                  {d.toLocaleDateString(undefined, { weekday: "short" }).slice(0, 2)}
                </span>
                <span className="text-base font-extrabold">{d.getDate()}</span>
              </button>
            </li>
          );
        })}
      </ol>
    </section>
  );
}
