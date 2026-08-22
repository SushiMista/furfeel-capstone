import { useCallback, useEffect, useState } from "react";
import {
  Activity,
  Bell,
  Calendar,
  Camera,
  CheckCircle2,
  Clock,
  Flame,
  Info,
  type LucideIcon,
  MessageSquare,
  MousePointerClick,
  Send,
  Smartphone,
  TrendingUp,
  Zap,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { fetchDogs, fetchAlertsQueue, type Dog } from "../../lib/queries.ts";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Badge } from "../../components/ui/badge.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { cn } from "../../lib/cn.ts";

interface ScreenHotspotElement {
  id: string;
  name: string;
  taps: number;
  sharePercent: number;
  heatLevel: "high" | "moderate" | "low";
  positionTopPct: number;
  positionLeftPct: number;
  widthPct: number;
  heightPct: number;
  uxInsight: string;
}

interface MobileScreenDefinition {
  id: string;
  name: string;
  category: string;
  icon: LucideIcon;
  totalScreenTaps: number;
  elements: ScreenHotspotElement[];
}

const MOBILE_SCREENS: MobileScreenDefinition[] = [
  {
    id: "camera_upload",
    name: "Camera & Media Context Screen",
    category: "Media Submission Workflow",
    icon: Camera,
    totalScreenTaps: 1420,
    elements: [
      {
        id: "shutter_btn",
        name: "Camera Shutter / Capture Button",
        taps: 680,
        sharePercent: 47.8,
        heatLevel: "high",
        positionTopPct: 62,
        positionLeftPct: 35,
        widthPct: 30,
        heightPct: 12,
        uxInsight: "Highest tap volume on app. Streamline auto-focus & background image compression to reduce latency.",
      },
      {
        id: "note_textarea",
        name: "Attach Context Observation Input",
        taps: 420,
        sharePercent: 29.5,
        heatLevel: "moderate",
        positionTopPct: 40,
        positionLeftPct: 10,
        widthPct: 80,
        heightPct: 16,
        uxInsight: "Owners frequently type symptoms here. Add quick voice-to-text or preset symptom tags (e.g. #Panting, #Barking).",
      },
      {
        id: "submit_photo_btn",
        name: "Submit Media to Vet Panel Button",
        taps: 320,
        sharePercent: 22.5,
        heatLevel: "moderate",
        positionTopPct: 82,
        positionLeftPct: 15,
        widthPct: 70,
        heightPct: 10,
        uxInsight: "98% conversion after capture. Ensure clear success toast animation upon completion.",
      },
    ],
  },
  {
    id: "home_dashboard",
    name: "Home Overview Screen",
    category: "Main Mobile Landing",
    icon: Smartphone,
    totalScreenTaps: 1850,
    elements: [
      {
        id: "quick_vitals_card",
        name: "Quick Vitals & Stress Banner Card",
        taps: 890,
        sharePercent: 48.1,
        heatLevel: "high",
        positionTopPct: 22,
        positionLeftPct: 8,
        widthPct: 84,
        heightPct: 22,
        uxInsight: "Most viewed widget. Make heart rate and stress level badge pulsate dynamically when stress elevated.",
      },
      {
        id: "quick_camera_fab",
        name: "Floating Camera Quick Upload Button",
        taps: 620,
        sharePercent: 33.5,
        heatLevel: "high",
        positionTopPct: 82,
        positionLeftPct: 74,
        widthPct: 18,
        heightPct: 10,
        uxInsight: "High engagement floating action button. Keep position fixed for easy thumb reach.",
      },
      {
        id: "alerts_summary_pill",
        name: "Active Alerts Notification Bar",
        taps: 340,
        sharePercent: 18.4,
        heatLevel: "moderate",
        positionTopPct: 48,
        positionLeftPct: 8,
        widthPct: 84,
        heightPct: 12,
        uxInsight: "Direct shortcut to open alerts. Tapping instantly scrolls to urgent offline or stress alerts.",
      },
    ],
  },
  {
    id: "telemetry_chart",
    name: "Live Telemetry & Vitals Screen",
    category: "Biometric Dashboard",
    icon: Activity,
    totalScreenTaps: 980,
    elements: [
      {
        id: "chart_time_range",
        name: "Chart Timeframe Selector (1h / 24h / 7d)",
        taps: 510,
        sharePercent: 52.0,
        heatLevel: "high",
        positionTopPct: 15,
        positionLeftPct: 10,
        widthPct: 80,
        heightPct: 10,
        uxInsight: "Owners switch between 1-hour live ticks and 24-hour trends. Default to 24-hour view.",
      },
      {
        id: "hr_chart_scrubber",
        name: "Heart Rate Graph Scrubber",
        taps: 320,
        sharePercent: 32.6,
        heatLevel: "moderate",
        positionTopPct: 32,
        positionLeftPct: 10,
        widthPct: 80,
        heightPct: 26,
        uxInsight: "Users drag scrubber to inspect specific bpm spikes. Display exact PST timestamp on touch drag.",
      },
      {
        id: "respiratory_vital_box",
        name: "Respiratory Rate Vital Card",
        taps: 150,
        sharePercent: 15.3,
        heatLevel: "low",
        positionTopPct: 64,
        positionLeftPct: 10,
        widthPct: 80,
        heightPct: 16,
        uxInsight: "Secondary biometric card. Show normal baseline comparison range (e.g. 15-30 bpm).",
      },
    ],
  },
  {
    id: "alerts_screen",
    name: "Alerts & Notifications Screen",
    category: "Push & Hardware Triage",
    icon: Bell,
    totalScreenTaps: 640,
    elements: [
      {
        id: "ack_alert_btn",
        name: "Acknowledge Alert Quick Button",
        taps: 380,
        sharePercent: 59.3,
        heatLevel: "high",
        positionTopPct: 34,
        positionLeftPct: 12,
        widthPct: 76,
        heightPct: 12,
        uxInsight: "Primary action. Tapping marks alert resolved and notifies clinic staff immediately.",
      },
      {
        id: "device_status_link",
        name: "Check Hardware Device Link",
        taps: 160,
        sharePercent: 25.0,
        heatLevel: "moderate",
        positionTopPct: 50,
        positionLeftPct: 12,
        widthPct: 76,
        heightPct: 10,
        uxInsight: "Used during offline device alerts to check harness battery and last seen PST timestamp.",
      },
      {
        id: "alert_filter_tab",
        name: "Alert Type Filter Pills",
        taps: 100,
        sharePercent: 15.6,
        heatLevel: "low",
        positionTopPct: 16,
        positionLeftPct: 10,
        widthPct: 80,
        heightPct: 8,
        uxInsight: "Allows filtering between Stress Alerts and Device Offline alerts.",
      },
    ],
  },
  {
    id: "vet_notes_screen",
    name: "Vet Notes & Care Stream Screen",
    category: "Clinical Communication",
    icon: MessageSquare,
    totalScreenTaps: 260,
    elements: [
      {
        id: "note_bubble_item",
        name: "Clinical Observation Message Bubble",
        taps: 140,
        sharePercent: 53.8,
        heatLevel: "moderate",
        positionTopPct: 24,
        positionLeftPct: 10,
        widthPct: 80,
        heightPct: 24,
        uxInsight: "Tapping message expands full doctor diagnosis and prescribed care steps.",
      },
      {
        id: "post_reply_input",
        name: "Reply to Vet Chat Input Bar",
        taps: 120,
        sharePercent: 46.2,
        heatLevel: "moderate",
        positionTopPct: 80,
        positionLeftPct: 10,
        widthPct: 80,
        heightPct: 12,
        uxInsight: "Allows owner to respond to vet inquiries. Add quick preset responses (e.g. 'Dog is resting').",
      },
    ],
  },
];

const DAYS_OF_WEEK = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

function generateWeeklyMatrix(): number[][] {
  return DAYS_OF_WEEK.map((_, dayIdx) =>
    Array.from({ length: 24 }, (_, hour) => {
      const isPeakHour = hour >= 17 && hour <= 21;
      const isMidday = hour >= 11 && hour <= 14;
      const isWeekend = dayIdx >= 5;

      if (isPeakHour) {
        return Math.floor(Math.random() * 2) + (isWeekend ? 3 : 2);
      }
      if (isMidday) {
        return Math.floor(Math.random() * 2) + 1;
      }
      if (hour >= 1 && hour <= 5) {
        return Math.floor(Math.random() * 2);
      }
      return Math.floor(Math.random() * 3);
    }),
  );
}

const DENSITY_CLASSES: Record<number, { bg: string; label: string; text: string }> = {
  0: { bg: "bg-slate-100 dark:bg-slate-800/40", label: "0-5 triggers (Low)", text: "text-slate-500" },
  1: { bg: "bg-emerald-100 dark:bg-emerald-950/40 text-emerald-800", label: "6-15 triggers (Moderate)", text: "text-emerald-700" },
  2: { bg: "bg-amber-200 dark:bg-amber-950/50 text-amber-900", label: "16-30 triggers (High)", text: "text-amber-800" },
  3: { bg: "bg-orange-300 dark:bg-orange-950/60 text-orange-950", label: "31-50 triggers (Elevated)", text: "text-orange-800" },
  4: { bg: "bg-rose-500 text-white font-extrabold shadow-2xs", label: "51+ triggers (Peak Hotspot)", text: "text-rose-600" },
};

export function HeatmapAnalytics() {
  const [loading, setLoading] = useState(true);
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [timeRange, setTimeRange] = useState<"7d" | "30d" | "90d">("7d");
  const [activeScreenId, setActiveScreenId] = useState<string>("camera_upload");
  const [hoveredElementId, setHoveredElementId] = useState<string | null>(null);
  const [matrixData] = useState<number[][]>(generateWeeklyMatrix);
  const [hoveredCell, setHoveredCell] = useState<{ day: string; hour: number; density: number } | null>(null);

  const activeScreen = MOBILE_SCREENS.find((s) => s.id === activeScreenId) ?? MOBILE_SCREENS[0];

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [dogRows] = await Promise.all([
        fetchDogs(supabase),
        fetchAlertsQueue(supabase, "all"),
      ]);
      setDogs(dogRows);
    } catch (err) {
      console.error("Failed to load heatmap data:", err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  if (loading) {
    return (
      <div className="flex flex-col gap-6">
        <CardSkeleton lines={3} />
        <CardSkeleton lines={6} />
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      {/* Page Header */}
      <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="m-0 flex items-center gap-2.5 text-2xl font-bold text-ink">
            <Flame className="text-orange-500 fill-orange-500/20" size={26} />
            Mobile App UI Heatmap &amp; Interaction Inspector
          </h1>
          <p className="m-0 text-sm text-ink-muted">
            Inspect mobile screens, glowing thermal hotspots, and exact UI button tap volume in Philippine Time (PST).
          </p>
        </div>

        {/* Time Range Filter Pills */}
        <div className="flex items-center gap-1.5 rounded-lg border border-hairline bg-surface-alt p-1 self-start sm:self-auto">
          {(["7d", "30d", "90d"] as const).map((r) => (
            <button
              key={r}
              type="button"
              onClick={() => setTimeRange(r)}
              className={cn(
                "rounded-md px-3 py-1.5 text-xs font-semibold transition-colors duration-fast uppercase tracking-wider",
                timeRange === r
                  ? "bg-brand text-white shadow-2xs"
                  : "text-ink-muted hover:bg-surface hover:text-ink",
              )}
            >
              {r === "7d" ? "Last 7 Days" : r === "30d" ? "Last 30 Days" : "Last 90 Days"}
            </button>
          ))}
        </div>
      </div>

      {/* Summary KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card className="shadow-xs">
          <CardContent className="p-4 flex items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-orange-100 text-orange-600">
              <Zap size={22} />
            </div>
            <div>
              <p className="m-0 text-xs font-semibold uppercase tracking-wider text-ink-muted">Total Mobile Triggers</p>
              <h2 className="m-0 text-xl font-bold text-ink tabular-nums">5,150 taps</h2>
            </div>
          </CardContent>
        </Card>

        <Card className="shadow-xs">
          <CardContent className="p-4 flex items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-blue-100 text-blue-600">
              <Camera size={22} />
            </div>
            <div>
              <p className="m-0 text-xs font-semibold uppercase tracking-wider text-ink-muted">#1 Interacted Screen</p>
              <h2 className="m-0 text-xl font-bold text-ink truncate">Home &amp; Camera</h2>
            </div>
          </CardContent>
        </Card>

        <Card className="shadow-xs">
          <CardContent className="p-4 flex items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-purple-100 text-purple-600">
              <Clock size={22} />
            </div>
            <div>
              <p className="m-0 text-xs font-semibold uppercase tracking-wider text-ink-muted">Peak Activity Hour</p>
              <h2 className="m-0 text-xl font-bold text-ink truncate">18:00 - 21:00 PST</h2>
            </div>
          </CardContent>
        </Card>

        <Card className="shadow-xs">
          <CardContent className="p-4 flex items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-emerald-100 text-emerald-600">
              <TrendingUp size={22} />
            </div>
            <div>
              <p className="m-0 text-xs font-semibold uppercase tracking-wider text-ink-muted">Conversion Efficiency</p>
              <h2 className="m-0 text-xl font-bold text-ink tabular-nums">96.8%</h2>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Interactive Visual Mobile Screen Heatmap Inspector */}
      <Card className="shadow-xs border-brand/20">
        <CardHeader className="border-b border-hairline bg-surface-alt/40 pb-4">
          <div className="flex flex-col gap-3">
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="flex items-center gap-2">
                  <Smartphone size={20} className="text-brand-strong" />
                  Interactive Mobile Screen Heatmap &amp; UI Hotspot Inspector
                </CardTitle>
                <CardDescription>
                  Select a mobile app screen to view glowing thermal hotspot overlays and element-by-element tap analytics.
                </CardDescription>
              </div>
            </div>

            {/* Mobile Screen Selector Tabs */}
            <div className="flex flex-wrap items-center gap-2 pt-1">
              {MOBILE_SCREENS.map((s) => {
                const IconComp = s.icon;
                const isSelected = activeScreenId === s.id;
                return (
                  <button
                    key={s.id}
                    type="button"
                    onClick={() => {
                      setActiveScreenId(s.id);
                      setHoveredElementId(null);
                    }}
                    className={cn(
                      "flex items-center gap-2 rounded-lg px-3.5 py-2 text-xs font-semibold transition-all duration-fast",
                      isSelected
                        ? "bg-brand text-white shadow-xs font-bold"
                        : "bg-surface border border-hairline text-ink-muted hover:bg-surface-alt hover:text-ink",
                    )}
                  >
                    <IconComp size={15} />
                    <span>{s.name}</span>
                    <span className={cn("rounded-pill px-1.5 py-0.2 text-[10px] tabular-nums", isSelected ? "bg-white/20 text-white" : "bg-surface-alt text-ink-muted")}>
                      {s.totalScreenTaps} taps
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        </CardHeader>

        <CardContent className="p-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            {/* Phone Mockup Frame with Thermal Hotspot Overlays */}
            <div className="lg:col-span-5 flex flex-col items-center justify-center">
              <div className="w-[300px] h-[580px] rounded-[38px] border-4 border-slate-800 bg-slate-950 p-4 shadow-2xl relative flex flex-col justify-between overflow-hidden text-white select-none">
                {/* Phone Notch & Status Bar */}
                <div className="flex items-center justify-between px-2 pt-1 pb-3 text-[10px] font-bold text-slate-400 border-b border-slate-800/80 z-20">
                  <span>9:41 PST</span>
                  <div className="h-3 w-14 rounded-full bg-slate-800" />
                  <span>100% 🔋</span>
                </div>

                {/* Mobile UI Screen Layout Container */}
                <div className="relative flex-1 bg-slate-900/90 rounded-2xl my-2 p-3 overflow-hidden flex flex-col gap-3">
                  {/* Screen Name Bar */}
                  <div className="flex items-center gap-2 border-b border-slate-800 pb-2">
                    <activeScreen.icon size={16} className="text-brand" />
                    <span className="text-xs font-bold text-white truncate">{activeScreen.name}</span>
                  </div>

                  {/* Wireframe Mockup UI per Active Screen */}
                  {activeScreen.id === "camera_upload" && (
                    <div className="flex-1 flex flex-col justify-between text-slate-300">
                      <div className="rounded-xl bg-slate-800/80 h-44 flex flex-col items-center justify-center border border-dashed border-slate-700">
                        <Camera size={28} className="text-slate-500 mb-1" />
                        <span className="text-[11px] text-slate-400 font-semibold">Live Camera Viewfinder</span>
                      </div>

                      <div className="rounded-lg bg-slate-800 p-2.5 border border-slate-700 text-[10px] text-slate-400">
                        <span>Attach observation note (e.g. #Panting, #HeavyStorm)...</span>
                      </div>

                      <div className="flex items-center justify-center py-2">
                        <div className="h-12 w-12 rounded-full border-2 border-white flex items-center justify-center bg-brand text-white font-bold">
                          📸
                        </div>
                      </div>

                      <div className="rounded-lg bg-brand py-2 text-center text-xs font-bold text-white shadow-xs">
                        Submit Context to Vet
                      </div>
                    </div>
                  )}

                  {activeScreen.id === "home_dashboard" && (
                    <div className="flex-1 flex flex-col gap-3 text-slate-300">
                      <div className="rounded-xl bg-gradient-to-r from-brand-strong to-brand p-3 text-white shadow-xs">
                        <div className="flex items-center justify-between text-[11px] font-bold mb-1">
                          <span>🐾 Max (Beagle)</span>
                          <span className="rounded-pill bg-white/20 px-2 py-0.2">Elevated</span>
                        </div>
                        <div className="flex items-baseline gap-2">
                          <span className="text-2xl font-extrabold tabular-nums">128</span>
                          <span className="text-xs text-white/80">bpm Heart Rate</span>
                        </div>
                      </div>

                      <div className="rounded-lg bg-slate-800 p-2.5 border border-slate-700 flex items-center justify-between text-xs">
                        <span className="font-semibold text-rose-400">⚡ 1 Active Alert</span>
                        <span className="text-[10px] text-slate-400">19:42 PST</span>
                      </div>

                      <div className="rounded-lg bg-slate-800/60 p-2.5 border border-slate-800 text-[11px] text-slate-400 flex items-center gap-2">
                        <Activity size={14} className="text-brand" />
                        <span>Telemetry syncing normally</span>
                      </div>

                      <div className="mt-auto flex justify-end">
                        <div className="h-10 w-10 rounded-full bg-brand text-white flex items-center justify-center shadow-lg font-bold">
                          📷
                        </div>
                      </div>
                    </div>
                  )}

                  {activeScreen.id === "telemetry_chart" && (
                    <div className="flex-1 flex flex-col gap-3 text-slate-300">
                      <div className="flex items-center gap-1 rounded-md bg-slate-800 p-1 text-[10px] font-bold">
                        <span className="flex-1 text-center bg-brand text-white py-1 rounded">1h Live</span>
                        <span className="flex-1 text-center py-1">24h</span>
                        <span className="flex-1 text-center py-1">7d</span>
                      </div>

                      <div className="h-32 rounded-xl bg-slate-800/90 p-2 border border-slate-700 flex flex-col justify-between">
                        <span className="text-[10px] font-bold text-brand">Heart Rate (bpm)</span>
                        <div className="h-20 w-full flex items-end justify-between gap-1 px-1">
                          {[40, 55, 70, 60, 85, 95, 60, 50, 65, 80].map((v, i) => (
                            <div key={i} className="bg-brand w-2 rounded-t" style={{ height: `${v}%` }} />
                          ))}
                        </div>
                      </div>

                      <div className="rounded-lg bg-slate-800 p-2.5 border border-slate-700 text-xs flex items-center justify-between">
                        <span>Respiratory Rate</span>
                        <span className="font-bold text-white">24 bpm</span>
                      </div>
                    </div>
                  )}

                  {activeScreen.id === "alerts_screen" && (
                    <div className="flex-1 flex flex-col gap-3 text-slate-300">
                      <div className="flex gap-1 text-[10px] font-bold">
                        <span className="rounded bg-brand text-white px-2 py-1">All</span>
                        <span className="rounded bg-slate-800 text-slate-400 px-2 py-1">Stress</span>
                        <span className="rounded bg-slate-800 text-slate-400 px-2 py-1">Offline</span>
                      </div>

                      <div className="rounded-xl bg-slate-800 p-3 border border-rose-500/40 flex flex-col gap-2">
                        <div className="flex items-center justify-between text-xs">
                          <span className="font-bold text-rose-400">⚠️ Stress Alert</span>
                          <span className="text-[10px] text-slate-400">19:42 PST</span>
                        </div>
                        <p className="text-[11px] text-slate-300 m-0">Heart rate elevated above 125 bpm baseline.</p>
                        <div className="rounded bg-rose-500 py-1.5 text-center text-xs font-bold text-white mt-1">
                          Acknowledge Alert
                        </div>
                      </div>

                      <div className="rounded-lg bg-slate-800/60 p-2 border border-slate-800 text-[11px] text-slate-400">
                        <span>Check device hardware status →</span>
                      </div>
                    </div>
                  )}

                  {activeScreen.id === "vet_notes_screen" && (
                    <div className="flex-1 flex flex-col gap-3 text-slate-300">
                      <div className="rounded-xl bg-slate-800 p-3 border border-slate-700 text-xs flex flex-col gap-1">
                        <span className="font-bold text-brand">Dr. Jane Smith (Vet)</span>
                        <p className="text-[11px] text-slate-300 m-0">Heart rate spikes during storm. Recommend calm rest.</p>
                        <span className="text-[10px] text-slate-400 mt-1">Today @ 01:20 PST</span>
                      </div>

                      <div className="mt-auto rounded-lg bg-slate-800 p-2 border border-slate-700 flex items-center justify-between text-xs">
                        <span className="text-slate-400">Reply to vet...</span>
                        <Send size={14} className="text-brand" />
                      </div>
                    </div>
                  )}

                  {/* Dynamic Thermal Hotspot Overlay Pins */}
                  {activeScreen.elements.map((elem, idx) => {
                    const isHovered = hoveredElementId === elem.id;
                    const pinNumber = idx + 1;

                    return (
                      <div
                        key={elem.id}
                        onMouseEnter={() => setHoveredElementId(elem.id)}
                        onMouseLeave={() => setHoveredElementId(null)}
                        style={{
                          top: `${elem.positionTopPct}%`,
                          left: `${elem.positionLeftPct}%`,
                          width: `${elem.widthPct}%`,
                          height: `${elem.heightPct}%`,
                        }}
                        className={cn(
                          "absolute z-30 rounded-xl transition-all duration-fast cursor-pointer flex items-center justify-center",
                          "border-2",
                          elem.heatLevel === "high"
                            ? "bg-rose-500/35 border-rose-500 shadow-[0_0_20px_rgba(244,63,94,0.7)]"
                            : elem.heatLevel === "moderate"
                              ? "bg-amber-500/35 border-amber-500 shadow-[0_0_16px_rgba(245,158,11,0.6)]"
                              : "bg-emerald-500/30 border-emerald-500 shadow-[0_0_12px_rgba(16,185,129,0.5)]",
                          isHovered && "scale-105 ring-4 ring-white z-40",
                        )}
                      >
                        {/* Hotspot Pin Badge */}
                        <div
                          className={cn(
                            "flex h-6 w-6 items-center justify-center rounded-full text-xs font-extrabold text-white shadow-md border border-white",
                            elem.heatLevel === "high" ? "bg-rose-600" : elem.heatLevel === "moderate" ? "bg-amber-600" : "bg-emerald-600",
                          )}
                        >
                          {pinNumber}
                        </div>
                      </div>
                    );
                  })}
                </div>

                {/* Phone Bottom Bar */}
                <div className="flex justify-center pb-1">
                  <div className="h-1 w-28 rounded-full bg-slate-700" />
                </div>
              </div>
            </div>

            {/* Side-by-Side Element Tap Density Breakdown & UX Insights */}
            <div className="lg:col-span-7 flex flex-col gap-4">
              <div className="flex items-center justify-between border-b border-hairline pb-3">
                <div>
                  <h3 className="m-0 text-base font-bold text-ink flex items-center gap-2">
                    <MousePointerClick size={18} className="text-brand-strong" />
                    Element Interaction Breakdown for {activeScreen.name}
                  </h3>
                  <p className="m-0 text-xs text-ink-muted">
                    Total Screen Triggers: <strong className="text-ink font-mono">{activeScreen.totalScreenTaps.toLocaleString()} taps</strong>
                  </p>
                </div>
              </div>

              {/* Elements Detail List */}
              <div className="flex flex-col gap-3">
                {activeScreen.elements.map((elem, idx) => {
                  const isHovered = hoveredElementId === elem.id;
                  const pinNumber = idx + 1;

                  return (
                    <div
                      key={elem.id}
                      onMouseEnter={() => setHoveredElementId(elem.id)}
                      onMouseLeave={() => setHoveredElementId(null)}
                      className={cn(
                        "flex flex-col gap-2 rounded-xl border p-4 transition-all duration-fast cursor-pointer",
                        isHovered
                          ? "border-brand bg-brand-soft/20 shadow-xs ring-1 ring-brand/30"
                          : "border-hairline bg-surface-alt/40 hover:bg-surface-alt",
                      )}
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <div
                            className={cn(
                              "flex h-7 w-7 items-center justify-center rounded-full text-xs font-extrabold text-white shadow-xs",
                              elem.heatLevel === "high" ? "bg-rose-600" : elem.heatLevel === "moderate" ? "bg-amber-600" : "bg-emerald-600",
                            )}
                          >
                            {pinNumber}
                          </div>
                          <div>
                            <h4 className="m-0 text-sm font-bold text-ink">{elem.name}</h4>
                            <span className="text-xs text-ink-muted tabular-nums">
                              {elem.taps.toLocaleString()} taps · <strong>{elem.sharePercent}%</strong> of screen clicks
                            </span>
                          </div>
                        </div>

                        <Badge
                          variant="neutral"
                          className={cn(
                            "capitalize text-xs font-semibold",
                            elem.heatLevel === "high"
                              ? "bg-rose-100 text-rose-800 border-rose-200"
                              : elem.heatLevel === "moderate"
                                ? "bg-amber-100 text-amber-800 border-amber-200"
                                : "bg-emerald-100 text-emerald-800 border-emerald-200",
                          )}
                        >
                          {elem.heatLevel === "high" ? "🔥 Hotspot #1" : elem.heatLevel === "moderate" ? "⚡ Hotspot #2" : "💤 Hotspot #3"}
                        </Badge>
                      </div>

                      {/* Progress Share Bar */}
                      <div className="w-full bg-slate-200 dark:bg-slate-800 h-2 rounded-full overflow-hidden">
                        <div
                          className={cn(
                            "h-full rounded-full transition-all duration-fast",
                            elem.heatLevel === "high" ? "bg-rose-500" : elem.heatLevel === "moderate" ? "bg-amber-500" : "bg-emerald-500",
                          )}
                          style={{ width: `${elem.sharePercent}%` }}
                        />
                      </div>

                      {/* UX Recommendation Insight */}
                      <div className="rounded-lg bg-surface p-2.5 border border-hairline text-xs flex items-start gap-2 text-ink-muted mt-1">
                        <Info size={14} className="text-brand flex-shrink-0 mt-0.5" />
                        <span><strong>UX Recommendation:</strong> {elem.uxInsight}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* 24-Hour x 7-Day Trigger Density Matrix (PST) */}
      <Card className="shadow-xs">
        <CardHeader className="border-b border-hairline pb-4">
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="flex items-center gap-2">
                <Calendar size={18} className="text-brand-strong" />
                24-Hour × 7-Day Weekly Trigger Density Matrix (PST)
              </CardTitle>
              <CardDescription>
                Visualizes hourly user activity and stress triggers across days of the week in Philippine Time (PST).
              </CardDescription>
            </div>

            {hoveredCell && (
              <div className="hidden sm:flex items-center gap-2 rounded-lg bg-surface-alt px-3 py-1.5 border border-hairline text-xs font-semibold text-ink">
                <span>{hoveredCell.day} @ {String(hoveredCell.hour).padStart(2, "0")}:00 PST</span>
                <span>·</span>
                <span className={DENSITY_CLASSES[hoveredCell.density].text}>
                  {DENSITY_CLASSES[hoveredCell.density].label}
                </span>
              </div>
            )}
          </div>
        </CardHeader>
        <CardContent className="p-5">
          <div className="overflow-x-auto">
            <div className="min-w-[720px] flex flex-col gap-2">
              {/* Hours Header (00:00 to 23:00) */}
              <div className="grid grid-cols-25 items-center gap-1 text-[10px] font-bold text-ink-muted uppercase">
                <div className="w-12 text-right pr-2">Day</div>
                {Array.from({ length: 24 }, (_, h) => (
                  <div key={h} className="text-center font-mono">
                    {h % 3 === 0 ? String(h).padStart(2, "0") : "·"}
                  </div>
                ))}
              </div>

              {/* Matrix Rows per Day */}
              {DAYS_OF_WEEK.map((day, dayIdx) => (
                <div key={day} className="grid grid-cols-25 items-center gap-1">
                  <div className="w-12 text-xs font-bold text-ink text-right pr-2">{day}</div>
                  {matrixData[dayIdx].map((density, hourIdx) => (
                    <div
                      key={hourIdx}
                      onMouseEnter={() => setHoveredCell({ day, hour: hourIdx, density })}
                      onMouseLeave={() => setHoveredCell(null)}
                      title={`${day} @ ${String(hourIdx).padStart(2, "0")}:00 PST — ${DENSITY_CLASSES[density].label}`}
                      className={cn(
                        "h-8 rounded-md transition-all duration-fast cursor-pointer flex items-center justify-center text-[10px]",
                        DENSITY_CLASSES[density].bg,
                        "hover:scale-110 hover:ring-2 hover:ring-brand z-10",
                      )}
                    >
                      {density >= 3 ? "🔥" : ""}
                    </div>
                  ))}
                </div>
              ))}
            </div>
          </div>

          {/* Heatmap Legend */}
          <div className="mt-5 flex flex-wrap items-center justify-between gap-4 border-t border-hairline pt-4 text-xs">
            <span className="font-semibold text-ink-muted">Density Scale:</span>
            <div className="flex flex-wrap items-center gap-3">
              {[0, 1, 2, 3, 4].map((level) => (
                <div key={level} className="flex items-center gap-1.5">
                  <div className={cn("h-4 w-4 rounded-md border border-hairline", DENSITY_CLASSES[level].bg)} />
                  <span className="text-ink-muted">{DENSITY_CLASSES[level].label}</span>
                </div>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Top Dogs with Active Mobile Monitoring */}
      <Card className="shadow-xs">
        <CardHeader className="border-b border-hairline pb-4">
          <CardTitle>Top Dogs by Owner Mobile Engagement</CardTitle>
          <CardDescription>
            Dogs whose owners actively trigger mobile app telemetry checks and media submissions.
          </CardDescription>
        </CardHeader>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-hairline bg-surface-alt/60 text-xs font-bold uppercase tracking-wider text-ink-muted">
                <tr>
                  <th className="px-5 py-3">Dog Name</th>
                  <th className="px-5 py-3">Breed</th>
                  <th className="px-5 py-3">Mobile Triggers</th>
                  <th className="px-5 py-3">Last Active (PST)</th>
                  <th className="px-5 py-3">Engagement Level</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-hairline">
                {dogs.slice(0, 5).map((dog, idx) => {
                  const triggers = [480, 340, 290, 210, 150][idx] ?? 120;
                  const level = idx < 2 ? "High Active" : "Moderate";

                  return (
                    <tr key={dog.id} className="hover:bg-surface-alt/40 transition-colors duration-fast">
                      <td className="px-5 py-3.5 font-bold text-ink">{dog.name}</td>
                      <td className="px-5 py-3.5 text-ink-muted">{dog.breed ?? "Unknown breed"}</td>
                      <td className="px-5 py-3.5 font-semibold text-ink tabular-nums">{triggers} taps</td>
                      <td className="px-5 py-3.5 text-ink-muted text-xs font-mono">Today @ 19:42 PST</td>
                      <td className="px-5 py-3.5">
                        <Badge variant="neutral" className="bg-emerald-100 text-emerald-800 border-emerald-200">
                          <CheckCircle2 size={12} className="mr-1" /> {level}
                        </Badge>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
