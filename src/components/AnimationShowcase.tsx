import { useMemo } from "react";
import { LottiePlayer } from "@/components/ui/lottie-player";
import office from "@/assets/office-hello-upload.json.asset.json";
import booking from "@/assets/appointment-booking-upload.json.asset.json";
import books from "@/assets/girl-books-upload.json.asset.json";
import hero from "@/assets/super-woman-upload.json.asset.json";

const animations = [office, booking, books, hero];

export function AnimationShowcase() {
  const chosen = useMemo(() => animations[new Date().getDay() % animations.length]!, []);
  return (
    <section className="surface-card flex items-center gap-4 overflow-hidden p-4 sm:p-5">
      <LottiePlayer src={chosen.url} className="h-24 w-28 shrink-0 sm:h-28 sm:w-36" />
      <div><p className="section-label">Daily motion</p><h2 className="mt-1 text-lg font-bold">Small steps build momentum.</h2><p className="mt-1 text-sm text-muted-foreground">Your study companion changes through the week.</p></div>
    </section>
  );
}