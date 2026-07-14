import {
  ArrowLeftIcon,
  CheckIcon,
  ChevronRightIcon,
  CircleCheckBigIcon,
  CircleHelpIcon,
  CopyIcon,
  HistoryIcon,
  HomeIcon,
  KeyboardIcon,
  MailIcon,
  MessageSquareIcon,
  MicIcon,
  MoreHorizontalIcon,
  SearchIcon,
  Settings2Icon,
  ShareIcon,
  SparklesIcon,
  SquareIcon,
  StickyNoteIcon,
  Trash2Icon,
  UsersIcon,
  WandSparklesIcon,
  ZapIcon,
} from "lucide-react";
import { AnimatePresence, MotionConfig, motion } from "motion/react";
import { type ReactNode, useMemo, useState } from "react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
} from "@/components/ui/drawer";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import { Switch } from "@/components/ui/switch";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";

type AppView =
  | "home"
  | "history"
  | "history-detail"
  | "license"
  | "modes"
  | "mode-detail"
  | "settings";

type PresetId =
  | "voice-to-text"
  | "message"
  | "mail"
  | "note"
  | "meeting"
  | "custom";

interface ModeItem {
  configuration: string;
  description: string;
  icon: typeof MicIcon;
  iconCustomized?: boolean;
  id: string;
  language: string;
  model: string;
  name: string;
  preset: PresetId;
}

interface HistoryItem {
  duration: string;
  id: string;
  mode: string;
  preview: string;
  processedText: string;
  rawText: string;
  segments: { text: string; timestamp: string }[];
  time: string;
  title: string;
  wordCount: number;
}

type TranscriptView = "raw" | "segmented" | "processed";

interface ScreenProps {
  navigate: (view: AppView, direction?: number) => void;
}

const viewOrder: AppView[] = ["home", "modes", "history", "settings"];

const presetMeta: Record<
  PresetId,
  {
    description: string;
    icon: typeof MicIcon;
    label: string;
    processing: string;
  }
> = {
  custom: {
    description: "Apply your own written instructions to every dictation.",
    icon: WandSparklesIcon,
    label: "Custom",
    processing: "Your instructions",
  },
  mail: {
    description: "Turn rough dictation into a clear, send-ready email.",
    icon: MailIcon,
    label: "Mail",
    processing: "AI formatted",
  },
  meeting: {
    description: "Turn a conversation into decisions, notes, and next steps.",
    icon: UsersIcon,
    label: "Meeting Summary",
    processing: "AI summary",
  },
  message: {
    description: "Clean up short messages while preserving your tone.",
    icon: MessageSquareIcon,
    label: "Message",
    processing: "AI formatted",
  },
  note: {
    description: "Organize spoken ideas into clear, structured notes.",
    icon: StickyNoteIcon,
    label: "Note",
    processing: "AI formatted",
  },
  "voice-to-text": {
    description:
      "Turn your voice into punctuated text with no AI post-processing.",
    icon: MicIcon,
    label: "Voice to Text",
    processing: "No AI post-processing",
  },
};

const presetOrder: PresetId[] = [
  "voice-to-text",
  "message",
  "mail",
  "note",
  "meeting",
  "custom",
];

const initialModes: ModeItem[] = [
  {
    configuration: "Voice to text · Voxtral Realtime",
    description:
      "Turn your voice into punctuated text with no AI post-processing.",
    icon: MicIcon,
    id: "default",
    language: "Automatic",
    model: "Voxtral Mini",
    name: "Default",
    preset: "voice-to-text",
  },
];

const modeIconOptions = [
  { icon: MicIcon, label: "Voice" },
  { icon: MessageSquareIcon, label: "Message" },
  { icon: MailIcon, label: "Mail" },
  { icon: StickyNoteIcon, label: "Note" },
  { icon: UsersIcon, label: "Meeting" },
  { icon: WandSparklesIcon, label: "Custom" },
  { icon: SparklesIcon, label: "Sparkles" },
  { icon: ZapIcon, label: "Quick" },
];

const historyItems: HistoryItem[] = [
  {
    duration: "0:42",
    id: "keyboard-flow",
    mode: "Default",
    preview:
      "The keyboard should feel invisible. I want to speak, stop, and have the final sentence appear immediately.",
    processedText:
      "The keyboard should feel invisible: speak, stop, and have the final sentence appear immediately. The microphone belongs at the bottom, where your thumb already expects it, and the recording state should remain obvious without taking over the screen.",
    rawText:
      "The keyboard should feel invisible. I want to speak, stop, and then just have the final sentence appear immediately. The microphone should be at the bottom because that's where my thumb already expects it, and the recording state should be obvious but not take over the whole screen.",
    segments: [
      {
        text: "The keyboard should feel invisible. I want to speak, stop, and have the final sentence appear immediately.",
        timestamp: "0:00",
      },
      {
        text: "The microphone belongs at the bottom, where my thumb already expects it.",
        timestamp: "0:17",
      },
      {
        text: "The recording state should stay obvious without taking over the screen.",
        timestamp: "0:31",
      },
    ],
    time: "Jul 12",
    title: "Invisible keyboard workflow",
    wordCount: 47,
  },
  {
    duration: "1:18",
    id: "onboarding",
    mode: "Notes",
    preview:
      "Plan the iPhone onboarding around keyboard access, microphone permission, and a short test dictation.",
    processedText:
      "Build onboarding around three visible checkpoints: enable the TimberVox keyboard, grant Full Access and microphone permission, then complete a short test dictation. Show each permission's current state and provide a direct route to the relevant iOS Settings page.",
    rawText:
      "Plan the iPhone onboarding around keyboard access, full access, microphone permission, and then maybe a short test dictation. I want the person to know what is missing and have a button that takes them to the right settings page instead of making them hunt for it.",
    segments: [
      {
        text: "Plan the iPhone onboarding around keyboard access and Full Access.",
        timestamp: "0:00",
      },
      {
        text: "Then request microphone permission and show what is still missing.",
        timestamp: "0:24",
      },
      {
        text: "Finish with a short test dictation and direct links into iOS Settings.",
        timestamp: "0:49",
      },
    ],
    time: "Jul 12",
    title: "iPhone onboarding checklist",
    wordCount: 63,
  },
  {
    duration: "0:27",
    id: "routing",
    mode: "Default",
    preview:
      "Voxtral realtime should remain the default route when the connection is healthy.",
    processedText:
      "Use Voxtral Realtime as the default route while the connection is healthy, then fall back cleanly without exposing provider details to the person dictating.",
    rawText:
      "Voxtral realtime should remain the default route when the connection is healthy, and if it isn't healthy then we should fall back cleanly without the user needing to understand any of that provider stuff.",
    segments: [
      {
        text: "Voxtral Realtime should remain the default route when the connection is healthy.",
        timestamp: "0:00",
      },
      {
        text: "Fallback should be clean and invisible to the person dictating.",
        timestamp: "0:15",
      },
    ],
    time: "Jul 11",
    title: "Default Voxtral routing",
    wordCount: 31,
  },
];

export function TimberVoxApp() {
  const [view, setView] = useState<AppView>("home");
  const [modeItems, setModeItems] = useState<ModeItem[]>(initialModes);
  const [activeModeId, setActiveModeId] = useState("default");
  const [selectedModeId, setSelectedModeId] = useState("default");
  const [selectedHistoryId, setSelectedHistoryId] = useState("keyboard-flow");

  const navigate = (nextView: AppView) => {
    setView(nextView);
  };

  const activeMode =
    modeItems.find((mode) => mode.id === activeModeId) ?? modeItems[0];
  const selectedMode =
    modeItems.find((mode) => mode.id === selectedModeId) ?? modeItems[0];
  const selectedHistory =
    historyItems.find((item) => item.id === selectedHistoryId) ??
    historyItems[0];
  const showBottomBar = viewOrder.includes(view);

  return (
    <MotionConfig
      reducedMotion="user"
      transition={{ duration: 0.34, ease: [0.32, 0.72, 0, 1] }}
    >
      <div className="relative size-full overflow-hidden bg-background text-foreground">
        <section className="absolute inset-0">
          {view === "home" ? (
            <HomeScreen
              activeMode={activeMode}
              modes={modeItems}
              navigate={navigate}
              onSelectMode={setActiveModeId}
            />
          ) : null}
          {view === "history" ? (
            <HistoryScreen
              navigate={navigate}
              onSelectHistory={setSelectedHistoryId}
            />
          ) : null}
          {view === "history-detail" ? (
            <HistoryDetailScreen item={selectedHistory} navigate={navigate} />
          ) : null}
          {view === "modes" ? (
            <ModesScreen
              activeModeId={activeModeId}
              modes={modeItems}
              navigate={navigate}
              onCreateMode={(preset) => {
                const meta = presetMeta[preset];
                const id = `mode-${Date.now()}`;
                const newMode: ModeItem = {
                  configuration: `${meta.label} · Voxtral Realtime`,
                  description: meta.description,
                  icon: meta.icon,
                  iconCustomized: false,
                  id,
                  language: preset === "custom" ? "English" : "Automatic",
                  model: "Voxtral Mini",
                  name: meta.label,
                  preset,
                };
                setModeItems((current) => [...current, newMode]);
                setSelectedModeId(id);
                navigate("mode-detail");
              }}
              onSelectMode={setSelectedModeId}
            />
          ) : null}
          {view === "mode-detail" ? (
            <ModeDetailScreen
              active={activeModeId === selectedMode.id}
              mode={selectedMode}
              navigate={navigate}
              onUpdateMode={(partial) =>
                setModeItems((current) =>
                  current.map((item) =>
                    item.id === selectedMode.id ? { ...item, ...partial } : item
                  )
                )
              }
              onUseMode={() => setActiveModeId(selectedMode.id)}
            />
          ) : null}
          {view === "settings" ? <SettingsScreen navigate={navigate} /> : null}
          {view === "license" ? <LicenseScreen navigate={navigate} /> : null}
        </section>

        {showBottomBar ? (
          <BottomBar activeView={view} navigate={navigate} />
        ) : null}
      </div>
    </MotionConfig>
  );
}

function HomeScreen({
  activeMode,
  modes,
  navigate,
  onSelectMode,
}: ScreenProps & {
  activeMode: ModeItem;
  modes: ModeItem[];
  onSelectMode: (id: string) => void;
}) {
  const [recording, setRecording] = useState(false);
  const [modePickerOpen, setModePickerOpen] = useState(false);

  return (
    <AppScreen bottomInset>
      <StatusBar />
      <header className="grid h-14 grid-cols-[2.5rem_1fr_2.5rem] items-center px-4">
        <span />
        <Button
          className="mx-auto rounded-full px-4"
          onClick={() => setModePickerOpen(true)}
          variant="secondary"
        >
          <WandSparklesIcon data-icon="inline-start" />
          {activeMode.name}
          <ChevronRightIcon data-icon="inline-end" />
        </Button>
        <span />
      </header>

      <div className="flex flex-1 flex-col px-5 pb-5">
        <div className="flex flex-1 flex-col items-center justify-center gap-7">
          <VoiceField recording={recording} />
          <AnimatePresence mode="wait">
            <motion.div
              animate={{ opacity: 1, y: 0 }}
              className="flex min-h-20 max-w-[310px] flex-col items-center gap-2 text-center"
              exit={{ opacity: 0, y: -8 }}
              initial={{ opacity: 0, y: 8 }}
              key={recording ? "recording" : "ready"}
            >
              <h1 className="font-semibold text-[1.65rem] tracking-[-0.04em]">
                {recording ? "Listening" : "Ready when you are"}
              </h1>
              <p className="text-muted-foreground text-sm leading-relaxed">
                {recording
                  ? "The live transcript appears here while the app records."
                  : `${activeMode.model} · ${activeMode.language}`}
              </p>
            </motion.div>
          </AnimatePresence>

          <motion.div whileTap={{ scale: 0.94 }}>
            <Button
              aria-label={recording ? "Stop recording" : "Start recording"}
              className={cn(
                "size-20 rounded-full shadow-[0_18px_55px_-14px_var(--primary)]",
                recording &&
                  "bg-recording text-recording-foreground hover:bg-recording/90"
              )}
              onClick={() => setRecording((value) => !value)}
            >
              {recording ? (
                <SquareIcon className="fill-current" />
              ) : (
                <MicIcon />
              )}
            </Button>
          </motion.div>
        </div>
      </div>

      <Drawer
        onOpenChange={setModePickerOpen}
        open={modePickerOpen}
        showSwipeHandle
      >
        <DrawerContent className="mx-auto max-w-[393px] rounded-t-[2rem]">
          <DrawerHeader>
            <DrawerTitle>Choose a mode</DrawerTitle>
            <DrawerDescription>
              Modes combine a preset, transcription model, and language.
            </DrawerDescription>
          </DrawerHeader>
          <div className="flex flex-col gap-1 px-4">
            {modes.map((mode) => {
              const Icon = mode.icon;
              return (
                <DrawerClose
                  className="flex items-center gap-3 rounded-2xl p-3 text-left hover:bg-accent"
                  key={mode.id}
                  onClick={() => onSelectMode(mode.id)}
                >
                  <span className="grid size-10 place-items-center rounded-xl bg-secondary text-primary">
                    <Icon className="size-5" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <strong className="block font-medium text-sm">
                      {mode.name}
                    </strong>
                    <small className="block truncate text-muted-foreground">
                      {mode.configuration}
                    </small>
                  </span>
                  {activeMode.id === mode.id ? (
                    <CheckIcon className="size-5 text-primary" />
                  ) : null}
                </DrawerClose>
              );
            })}
          </div>
          <DrawerFooter>
            <DrawerClose
              onClick={() => navigate("modes")}
              render={<Button variant="secondary" />}
            >
              Manage modes
            </DrawerClose>
          </DrawerFooter>
        </DrawerContent>
      </Drawer>
    </AppScreen>
  );
}

function VoiceField({ recording }: { recording: boolean }) {
  const bars = [
    { height: 20, id: "wave-1" },
    { height: 34, id: "wave-2" },
    { height: 52, id: "wave-3" },
    { height: 74, id: "wave-4" },
    { height: 42, id: "wave-5" },
    { height: 88, id: "wave-6" },
    { height: 60, id: "wave-7" },
    { height: 34, id: "wave-8" },
    { height: 70, id: "wave-9" },
    { height: 46, id: "wave-10" },
    { height: 28, id: "wave-11" },
  ];

  return (
    <motion.div
      animate={{ scale: recording ? 1.04 : 1 }}
      className={cn("voice-field", recording && "voice-field-recording")}
    >
      <motion.div
        animate={{
          opacity: recording ? 0.72 : 0.28,
          scale: recording ? 1.08 : 0.88,
        }}
        className="absolute inset-8 rounded-full bg-primary/30 blur-3xl"
      />
      <div className="relative flex h-24 items-center justify-center gap-[5px]">
        {bars.map(({ height, id }) => (
          <motion.i
            animate={{
              height: recording
                ? [height * 0.45, height, height * 0.58]
                : height * 0.42,
              opacity: recording ? 1 : 0.7,
            }}
            className="w-1 rounded-full bg-current"
            key={id}
            transition={{
              duration: 0.72 + (height % 7) * 0.08,
              repeat: recording ? Number.POSITIVE_INFINITY : 0,
              repeatType: "mirror",
            }}
          />
        ))}
      </div>
    </motion.div>
  );
}

function HistoryScreen({
  navigate,
  onSelectHistory,
}: ScreenProps & { onSelectHistory: (id: string) => void }) {
  const [searching, setSearching] = useState(false);
  const [query, setQuery] = useState("");
  const filteredItems = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) {
      return historyItems;
    }
    return historyItems.filter((item) =>
      [item.title, item.preview, item.mode]
        .join(" ")
        .toLowerCase()
        .includes(normalized)
    );
  }, [query]);

  return (
    <AppScreen bottomInset>
      <StatusBar time="4:53" />
      <AppHeader
        action={
          <Button
            aria-label={searching ? "Close search" : "Search history"}
            onClick={() => {
              setSearching((value) => !value);
              if (searching) {
                setQuery("");
              }
            }}
            size="icon"
            variant="ghost"
          >
            {searching ? <ArrowLeftIcon /> : <SearchIcon />}
          </Button>
        }
        title="History"
      />
      <AnimatePresence initial={false}>
        {searching ? (
          <motion.div
            animate={{ height: 52, opacity: 1 }}
            className="overflow-hidden px-5"
            exit={{ height: 0, opacity: 0 }}
            initial={{ height: 0, opacity: 0 }}
          >
            <Input
              aria-label="Search dictations"
              autoFocus
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search titles, text, or modes"
              value={query}
            />
          </motion.div>
        ) : null}
      </AnimatePresence>
      <ScrollArea className="min-h-0 flex-1">
        <div className="flex flex-col gap-3 px-5 pt-3 pb-6">
          <div className="flex items-center justify-between py-1">
            <span className="font-medium text-muted-foreground text-xs uppercase tracking-[0.14em]">
              Recent
            </span>
            <Badge variant="secondary">
              {filteredItems.length}{" "}
              {filteredItems.length === 1 ? "dictation" : "dictations"}
            </Badge>
          </div>
          {filteredItems.map((item) => (
            <button
              className="group rounded-2xl text-left outline-none focus-visible:ring-2 focus-visible:ring-ring"
              key={item.id}
              onClick={() => {
                onSelectHistory(item.id);
                navigate("history-detail");
              }}
              type="button"
            >
              <Card className="gap-3 py-4 transition-colors group-hover:bg-accent/60">
                <CardHeader>
                  <CardTitle className="pr-14 text-[0.94rem]">
                    {item.title}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="line-clamp-3 text-muted-foreground text-sm leading-relaxed">
                    {item.preview}
                  </p>
                  <div className="mt-3 flex items-center justify-between border-t pt-3 text-[0.68rem] text-muted-foreground">
                    <span>
                      {item.wordCount} words · {formatDuration(item.duration)}
                    </span>
                    <span>{item.time}</span>
                  </div>
                </CardContent>
              </Card>
            </button>
          ))}
          {filteredItems.length === 0 ? (
            <p className="py-12 text-center text-muted-foreground text-sm">
              No matching dictations.
            </p>
          ) : null}
        </div>
      </ScrollArea>
    </AppScreen>
  );
}

function HistoryDetailScreen({
  item,
  navigate,
}: ScreenProps & { item: HistoryItem }) {
  const [transcriptView, setTranscriptView] =
    useState<TranscriptView>("processed");

  return (
    <AppScreen>
      <StatusBar time="4:53" />
      <header className="flex h-14 shrink-0 items-center justify-between px-3">
        <Button
          aria-label="Back"
          onClick={() => navigate("history", -1)}
          size="icon"
          variant="ghost"
        >
          <ArrowLeftIcon />
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger
            render={
              <Button
                aria-label="Recording actions"
                size="icon"
                variant="ghost"
              />
            }
          >
            <MoreHorizontalIcon />
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-48">
            <DropdownMenuGroup>
              <DropdownMenuItem>
                <CopyIcon /> Copy transcript
              </DropdownMenuItem>
              <DropdownMenuItem>
                <ShareIcon /> Share
              </DropdownMenuItem>
              <DropdownMenuItem>
                <SparklesIcon /> Reprocess
              </DropdownMenuItem>
            </DropdownMenuGroup>
            <DropdownMenuSeparator />
            <DropdownMenuItem variant="destructive">Delete</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </header>
      <ScrollArea className="min-h-0 flex-1">
        <div className="flex flex-col gap-5 px-5 pt-5 pb-36">
          <TranscriptContent item={item} view={transcriptView} />
        </div>
      </ScrollArea>
      <div className="absolute inset-x-0 bottom-0 border-t bg-background px-5 pt-3 pb-5">
        <TranscriptViewControl
          onChange={setTranscriptView}
          value={transcriptView}
        />
        <div className="mt-3 flex items-center justify-between gap-3 text-muted-foreground text-xs">
          <span>
            {item.wordCount} words · {formatDuration(item.duration)}
          </span>
          <span>{item.time}</span>
        </div>
      </div>
    </AppScreen>
  );
}

function TranscriptViewControl({
  onChange,
  value,
}: {
  onChange: (value: TranscriptView) => void;
  value: TranscriptView;
}) {
  return (
    <Tabs
      onValueChange={(nextValue) => onChange(nextValue as TranscriptView)}
      value={value}
    >
      <TabsList className="grid w-full grid-cols-3">
        <TabsTrigger value="raw">Raw</TabsTrigger>
        <TabsTrigger value="segmented">Segmented</TabsTrigger>
        <TabsTrigger value="processed">Processed</TabsTrigger>
      </TabsList>
    </Tabs>
  );
}

function formatDuration(duration: string) {
  const [minutes, seconds] = duration.split(":").map(Number);
  if (!minutes) {
    return `${seconds} sec`;
  }
  return seconds ? `${minutes} min ${seconds} sec` : `${minutes} min`;
}

function TranscriptContent({
  item,
  view,
}: {
  item: HistoryItem;
  view: TranscriptView;
}) {
  if (view === "segmented") {
    return (
      <div className="flex flex-col gap-3">
        {item.segments.map((segment) => (
          <div
            className="grid grid-cols-[2.5rem_1fr] gap-3 text-sm leading-relaxed"
            key={`${item.id}-${segment.timestamp}`}
          >
            <button
              className="pt-0.5 text-left font-medium text-primary text-xs"
              type="button"
            >
              {segment.timestamp}
            </button>
            <p>{segment.text}</p>
          </div>
        ))}
      </div>
    );
  }

  return (
    <p className="text-[0.94rem] text-foreground/90 leading-[1.72]">
      {view === "raw" ? item.rawText : item.processedText}
    </p>
  );
}

function ModesScreen({
  activeModeId,
  modes,
  navigate,
  onCreateMode,
  onSelectMode,
}: ScreenProps & {
  activeModeId: string;
  modes: ModeItem[];
  onCreateMode: (preset: PresetId) => void;
  onSelectMode: (id: string) => void;
}) {
  const suggestedPresets: PresetId[] = ["message", "meeting", "note", "custom"];

  return (
    <AppScreen bottomInset>
      <StatusBar time="4:51" />
      <AppHeader title="Modes" />
      <ScrollArea className="min-h-0 flex-1">
        <div className="flex flex-col gap-3 px-5 pt-3 pb-28">
          <h2 className="font-medium text-muted-foreground text-xs uppercase tracking-[0.14em]">
            Your modes
          </h2>
          {modes.map((mode) => {
            const Icon = mode.icon;
            return (
              <button
                className="group rounded-2xl text-left outline-none focus-visible:ring-2 focus-visible:ring-ring"
                key={mode.id}
                onClick={() => {
                  onSelectMode(mode.id);
                  navigate("mode-detail");
                }}
                type="button"
              >
                <Card
                  className="transition-colors group-hover:bg-accent/60"
                  size="sm"
                >
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <span className="grid size-8 place-items-center rounded-lg bg-secondary text-primary">
                        <Icon className="size-4" />
                      </span>
                      {mode.name}
                      {activeModeId === mode.id ? (
                        <Badge className="bg-success/15 text-success">
                          Active
                        </Badge>
                      ) : null}
                    </CardTitle>
                    <CardDescription className="pl-10">
                      {mode.description}
                    </CardDescription>
                    <p className="pl-10 text-[0.68rem] text-muted-foreground/70">
                      {mode.configuration}
                    </p>
                    <CardAction className="self-center">
                      <ChevronRightIcon className="size-4 text-muted-foreground" />
                    </CardAction>
                  </CardHeader>
                </Card>
              </button>
            );
          })}
          <section className="mt-4">
            <h2 className="font-medium text-muted-foreground text-xs uppercase tracking-[0.14em]">
              Create from a preset
            </h2>
            <div className="mt-3 grid grid-cols-2 gap-2">
              {suggestedPresets.map((preset) => {
                const meta = presetMeta[preset];
                const Icon = meta.icon;
                return (
                  <button
                    className="flex min-h-28 flex-col items-start gap-2 rounded-2xl border bg-card p-4 text-left transition-colors hover:bg-accent"
                    key={preset}
                    onClick={() => onCreateMode(preset)}
                    type="button"
                  >
                    <Icon className="size-5 text-primary" />
                    <strong className="text-sm">{meta.label}</strong>
                    <span className="text-muted-foreground text-xs leading-4">
                      {meta.description}
                    </span>
                  </button>
                );
              })}
            </div>
          </section>
        </div>
      </ScrollArea>
      <div className="absolute inset-x-0 bottom-[4.9rem] border-t bg-background px-5 py-3">
        <Button
          className="h-11 w-full rounded-xl"
          onClick={() => onCreateMode("custom")}
          variant="secondary"
        >
          Create mode
        </Button>
      </div>
    </AppScreen>
  );
}

function ModeDetailScreen({
  active,
  mode,
  navigate,
  onUpdateMode,
  onUseMode,
}: ScreenProps & {
  active: boolean;
  mode: ModeItem;
  onUpdateMode: (partial: Partial<ModeItem>) => void;
  onUseMode: () => void;
}) {
  const [preset, setPreset] = useState<PresetId>(mode.preset);
  const [audioModel, setAudioModel] = useState(mode.model);
  const [language, setLanguage] = useState(mode.language);
  const [languageModel, setLanguageModel] = useState("Mistral Small");
  const [customInstructions, setCustomInstructions] = useState("");
  const [identifySpeakers, setIdentifySpeakers] = useState(false);
  const [realtime, setRealtime] = useState(true);
  const [iconPickerOpen, setIconPickerOpen] = useState(false);
  const [languagePickerOpen, setLanguagePickerOpen] = useState(false);
  const [languageModelPickerOpen, setLanguageModelPickerOpen] = useState(false);
  const [modelPickerOpen, setModelPickerOpen] = useState(false);
  const [presetPickerOpen, setPresetPickerOpen] = useState(false);
  const [realtimeInfoOpen, setRealtimeInfoOpen] = useState(false);
  const ModeIcon = mode.icon;
  const usesLanguageModel = preset !== "voice-to-text";

  return (
    <AppScreen>
      <StatusBar time="4:51" />
      <header className="grid h-14 shrink-0 grid-cols-[2.5rem_1fr_2.5rem] items-center border-b px-3">
        <Button
          aria-label="Back"
          onClick={() => navigate("modes", -1)}
          size="icon"
          variant="ghost"
        >
          <ArrowLeftIcon />
        </Button>
        <div className="flex min-w-0 items-center justify-center gap-1">
          <Button
            aria-label="Change mode icon"
            onClick={() => setIconPickerOpen(true)}
            size="icon"
            variant="ghost"
          >
            <ModeIcon />
          </Button>
          <Input
            aria-label="Mode name"
            className="h-9 min-w-0 border-0 bg-transparent px-1 text-center font-semibold shadow-none focus-visible:ring-0"
            onChange={(event) => onUpdateMode({ name: event.target.value })}
            value={mode.name}
          />
        </div>
        <span />
      </header>
      <ScrollArea className="min-h-0 flex-1">
        <div className="flex flex-col gap-4 px-5 pt-4 pb-28">
          <Card>
            <CardContent className="flex flex-col">
              <ValueRow
                label="Preset"
                onClick={() => setPresetPickerOpen(true)}
                value={presetMeta[preset].label}
              />
              <Separator />
              <ValueRow
                label="Language"
                onClick={() => setLanguagePickerOpen(true)}
                value={language}
              />
              <Separator />
              <ValueRow
                label="Voice model"
                onClick={() => setModelPickerOpen(true)}
                value={audioModel}
              />
              <Separator />
              <ControlRow label="Realtime">
                <div className="flex items-center gap-2">
                  <Button
                    aria-label="About realtime"
                    onClick={() => setRealtimeInfoOpen(true)}
                    size="icon-xs"
                    variant="ghost"
                  >
                    <CircleHelpIcon />
                  </Button>
                  <Switch checked={realtime} onCheckedChange={setRealtime} />
                </div>
              </ControlRow>
              {usesLanguageModel ? (
                <>
                  <Separator />
                  <ValueRow
                    label="Language model"
                    onClick={() => setLanguageModelPickerOpen(true)}
                    value={languageModel}
                  />
                </>
              ) : null}
              {preset === "meeting" ? (
                <>
                  <Separator />
                  <ControlRow label="Identify speakers">
                    <Switch
                      checked={identifySpeakers}
                      onCheckedChange={setIdentifySpeakers}
                    />
                  </ControlRow>
                </>
              ) : null}
            </CardContent>
          </Card>

          {preset === "custom" ? (
            <Card>
              <CardContent className="flex flex-col gap-2">
                <label
                  className="font-medium text-sm"
                  htmlFor="mode-instructions"
                >
                  Custom instructions
                </label>
                <Textarea
                  id="mode-instructions"
                  onChange={(event) =>
                    setCustomInstructions(event.target.value)
                  }
                  placeholder="Describe how TimberVox should transform your dictation…"
                  value={customInstructions}
                />
              </CardContent>
            </Card>
          ) : null}
        </div>
      </ScrollArea>

      <Drawer
        onOpenChange={setIconPickerOpen}
        open={iconPickerOpen}
        showSwipeHandle
      >
        <DrawerContent className="mx-auto max-w-[393px] rounded-t-[2rem]">
          <DrawerHeader>
            <DrawerTitle>Mode icon</DrawerTitle>
            <DrawerDescription>Choose an icon for this mode.</DrawerDescription>
          </DrawerHeader>
          <div className="grid grid-cols-4 gap-2 px-4 pb-6">
            {modeIconOptions.map(({ icon: Icon, label }) => (
              <DrawerClose
                aria-label={label}
                className="grid aspect-square place-items-center rounded-2xl border hover:bg-accent"
                key={label}
                onClick={() =>
                  onUpdateMode({ icon: Icon, iconCustomized: true })
                }
              >
                <Icon className="size-5" />
              </DrawerClose>
            ))}
          </div>
        </DrawerContent>
      </Drawer>

      <Drawer
        onOpenChange={setModelPickerOpen}
        open={modelPickerOpen}
        showSwipeHandle
      >
        <ChoiceDrawerContent
          onSelect={setAudioModel}
          options={["Voxtral Mini", "Deepgram Nova-3", "ElevenLabs Scribe v2"]}
          selected={audioModel}
          title="Audio model"
        />
      </Drawer>

      <Drawer
        onOpenChange={setLanguageModelPickerOpen}
        open={languageModelPickerOpen}
        showSwipeHandle
      >
        <ChoiceDrawerContent
          onSelect={setLanguageModel}
          options={["Mistral Small", "Mistral Medium", "Gemini Flash"]}
          selected={languageModel}
          title="Language model"
        />
      </Drawer>

      <Drawer
        onOpenChange={setLanguagePickerOpen}
        open={languagePickerOpen}
        showSwipeHandle
      >
        <ChoiceDrawerContent
          onSelect={setLanguage}
          options={[
            "Automatic",
            "English",
            "Spanish",
            "French",
            "German",
            "Portuguese",
            "Russian",
          ]}
          selected={language}
          title="Language"
        />
      </Drawer>

      <Drawer
        onOpenChange={setPresetPickerOpen}
        open={presetPickerOpen}
        showSwipeHandle
      >
        <DrawerContent className="mx-auto max-w-[393px] rounded-t-[2rem]">
          <DrawerHeader className="gap-2 px-5 pt-5 pb-4">
            <DrawerTitle>Preset</DrawerTitle>
            <DrawerDescription className="leading-relaxed">
              Choose how finished text should be processed.
            </DrawerDescription>
          </DrawerHeader>
          <div className="grid grid-cols-2 gap-2 px-4 pb-6">
            {presetOrder.map((id) => {
              const meta = presetMeta[id];
              const Icon = meta.icon;
              return (
                <DrawerClose
                  className={cn(
                    "flex min-h-24 flex-col items-start gap-2 rounded-2xl border p-3 text-left hover:bg-accent",
                    preset === id && "border-primary/50 bg-primary/10"
                  )}
                  key={id}
                  onClick={() => {
                    setPreset(id);
                    onUpdateMode({
                      description: meta.description,
                      ...(mode.iconCustomized ? {} : { icon: meta.icon }),
                      preset: id,
                    });
                  }}
                >
                  <span className="flex w-full items-center justify-between">
                    <Icon className="size-5 text-primary" />
                    {preset === id ? (
                      <CheckIcon className="size-4 text-primary" />
                    ) : null}
                  </span>
                  <strong className="font-medium text-sm">{meta.label}</strong>
                  <span className="text-muted-foreground text-xs leading-4">
                    {meta.description}
                  </span>
                  <span className="mt-auto text-[0.65rem] text-primary">
                    {meta.processing}
                  </span>
                </DrawerClose>
              );
            })}
          </div>
        </DrawerContent>
      </Drawer>

      <Dialog onOpenChange={setRealtimeInfoOpen} open={realtimeInfoOpen}>
        <DialogContent className="max-w-xs">
          <DialogHeader>
            <DialogTitle>Realtime transcription</DialogTitle>
            <DialogDescription>
              Words appear while you speak in the app. The keyboard inserts the
              completed text when recording stops.
            </DialogDescription>
          </DialogHeader>
        </DialogContent>
      </Dialog>
      <div className="absolute inset-x-0 bottom-0 border-t bg-background px-5 py-3">
        <Button className="h-12 w-full rounded-xl" onClick={onUseMode}>
          {active ? <CheckIcon data-icon="inline-start" /> : null}
          Use mode
        </Button>
      </div>
    </AppScreen>
  );
}

function SettingsScreen({ navigate }: ScreenProps) {
  const [keepAudio, setKeepAudio] = useState(true);
  const [retention, setRetention] = useState("30 days");
  const [retentionOpen, setRetentionOpen] = useState(false);

  return (
    <AppScreen bottomInset>
      <StatusBar time="4:50" />
      <AppHeader title="Settings" />
      <ScrollArea className="min-h-0 flex-1">
        <div className="flex flex-col gap-4 px-5 pt-3 pb-8">
          <SettingsCard
            description="Typing behavior in the TimberVox keyboard"
            title="Keyboard"
          >
            <ControlRow label="Predictive text">
              <Switch defaultChecked />
            </ControlRow>
            <Separator />
            <ControlRow label="Swipe typing">
              <Switch defaultChecked />
            </ControlRow>
            <Separator />
            <ControlRow label="Haptic feedback">
              <Switch defaultChecked />
            </ControlRow>
          </SettingsCard>

          <SettingsCard
            description="Control saved audio on this iPhone"
            title="Storage & privacy"
          >
            <ControlRow icon={MicIcon} label="Keep audio recordings">
              <Switch checked={keepAudio} onCheckedChange={setKeepAudio} />
            </ControlRow>
            <Separator />
            <ValueRow
              disabled={!keepAudio}
              label="Delete audio after"
              onClick={() => setRetentionOpen(true)}
              value={keepAudio ? retention : "Immediately"}
            />
            <Separator />
            <InfoRow label="Storage used" value="184 MB" />
            <Separator />
            <Button
              className="mt-2 justify-start px-0 text-destructive hover:text-destructive"
              variant="ghost"
            >
              <Trash2Icon data-icon="inline-start" />
              Clear recordings
            </Button>
            <p className="pt-2 text-muted-foreground text-xs leading-relaxed">
              Transcript history is kept separately from audio recordings.
            </p>
          </SettingsCard>

          <button
            className="rounded-2xl text-left outline-none focus-visible:ring-2 focus-visible:ring-ring"
            onClick={() => navigate("license")}
            type="button"
          >
            <Card className="transition-colors hover:bg-accent/60" size="sm">
              <CardHeader>
                <CardTitle>TimberVox Pro</CardTitle>
                <CardDescription>Cloud Access · App Store</CardDescription>
                <CardAction className="flex items-center gap-2">
                  <Badge className="bg-success/15 text-success">Active</Badge>
                  <ChevronRightIcon className="size-4 text-muted-foreground" />
                </CardAction>
              </CardHeader>
            </Card>
          </button>

          <section aria-labelledby="access-heading">
            <div className="mb-2 flex items-center justify-between">
              <h2 className="font-medium text-sm" id="access-heading">
                Access
              </h2>
              <span className="flex items-center gap-1 text-success text-xs">
                <CircleCheckBigIcon className="size-3.5" /> Ready
              </span>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <AccessTile
                icon={KeyboardIcon}
                label="Keyboard"
                value="Enabled"
              />
              <AccessTile
                icon={CircleCheckBigIcon}
                label="Full Access"
                value="On"
              />
              <AccessTile icon={MicIcon} label="Microphone" value="Granted" />
              <AccessTile
                icon={SparklesIcon}
                label="Background"
                value="Ready"
              />
            </div>
          </section>
        </div>
      </ScrollArea>

      <Drawer
        onOpenChange={setRetentionOpen}
        open={retentionOpen}
        showSwipeHandle
      >
        <ChoiceDrawerContent
          description="Older audio is deleted from this iPhone automatically."
          onSelect={setRetention}
          options={["7 days", "30 days", "90 days", "Never"]}
          selected={retention}
          title="Delete audio after"
        />
      </Drawer>
    </AppScreen>
  );
}

function LicenseScreen({ navigate }: ScreenProps) {
  return (
    <AppScreen>
      <StatusBar time="4:50" />
      <DetailHeader
        onBack={() => navigate("settings", -1)}
        title="TimberVox Pro"
      />
      <ScrollArea className="min-h-0 flex-1">
        <div className="flex flex-col gap-4 px-5 pt-5 pb-8">
          <Card className="border-success/25 bg-success/5">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-lg">
                <CircleCheckBigIcon className="size-5 text-success" />
                Active
              </CardTitle>
              <CardDescription>
                Hosted transcription and text processing are available on this
                device.
              </CardDescription>
            </CardHeader>
          </Card>

          <SettingsCard
            description="Purchase details from the App Store"
            title="License"
          >
            <InfoRow label="Plan" value="Cloud Access" />
            <Separator />
            <InfoRow label="Billing" value="$7.99 / month" />
            <Separator />
            <InfoRow label="Renews" value="Aug 11, 2026" />
            <Separator />
            <InfoRow label="Account" value="App Store" />
          </SettingsCard>

          <SettingsCard
            description="RevenueCat entitlements used by TimberVox"
            title="Entitlements"
          >
            <InfoRow
              label="Cloud Access"
              value="Active"
              valueClassName="text-success"
            />
            <Separator />
            <InfoRow label="Local Pro" value="Not owned" />
          </SettingsCard>

          <Button>Manage subscription</Button>
          <Button variant="secondary">Restore purchases</Button>
        </div>
      </ScrollArea>
    </AppScreen>
  );
}

function AccessTile({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof MicIcon;
  label: string;
  value: string;
}) {
  return (
    <Card className="gap-2 p-3" size="sm">
      <span className="flex items-center justify-between">
        <Icon className="size-4 text-success" />
        <i className="size-2 rounded-full bg-success shadow-[0_0_12px_var(--success)]" />
      </span>
      <span className="font-medium text-xs">{label}</span>
      <span className="text-[0.68rem] text-muted-foreground">{value}</span>
    </Card>
  );
}

function ChoiceDrawerContent({
  description,
  onSelect,
  options,
  selected,
  title,
}: {
  description?: string;
  onSelect: (value: string) => void;
  options: string[];
  selected: string;
  title: string;
}) {
  return (
    <DrawerContent className="mx-auto max-w-[393px] rounded-t-[2rem]">
      <DrawerHeader>
        <DrawerTitle>{title}</DrawerTitle>
        {description ? (
          <DrawerDescription>{description}</DrawerDescription>
        ) : null}
      </DrawerHeader>
      <div className="flex flex-col gap-1 px-4 pb-5">
        {options.map((option) => (
          <DrawerClose
            className={cn(
              "flex min-h-12 items-center justify-between rounded-xl px-3 text-left text-sm hover:bg-accent",
              option === selected && "bg-primary/10"
            )}
            key={option}
            onClick={() => onSelect(option)}
          >
            {option}
            {option === selected ? (
              <CheckIcon className="size-4 text-primary" />
            ) : null}
          </DrawerClose>
        ))}
      </div>
    </DrawerContent>
  );
}

function BottomBar({
  activeView,
  navigate,
}: {
  activeView: AppView;
  navigate: (view: AppView, direction?: number) => void;
}) {
  const destinations = [
    { icon: HomeIcon, label: "Record", view: "home" as const },
    { icon: WandSparklesIcon, label: "Modes", view: "modes" as const },
    { icon: HistoryIcon, label: "History", view: "history" as const },
    { icon: Settings2Icon, label: "Settings", view: "settings" as const },
  ];

  return (
    <nav className="absolute inset-x-3 bottom-3 z-20 flex h-16 items-center rounded-[1.35rem] border bg-background/88 p-1.5 shadow-2xl backdrop-blur-2xl">
      {destinations.map(({ icon: Icon, label, view }) => (
        <Button
          aria-current={activeView === view ? "page" : undefined}
          className={cn(
            "relative h-full flex-1 flex-col gap-1 rounded-2xl text-[0.68rem] text-muted-foreground",
            activeView === view && "bg-secondary text-foreground"
          )}
          key={view}
          onClick={() => {
            const currentIndex = viewOrder.indexOf(activeView);
            const nextIndex = viewOrder.indexOf(view);
            navigate(view, nextIndex >= currentIndex ? 1 : -1);
          }}
          variant="ghost"
        >
          <Icon />
          {label}
          {activeView === view ? (
            <motion.span
              className="absolute bottom-1 h-0.5 w-5 rounded-full bg-primary"
              layoutId="bottom-navigation-indicator"
            />
          ) : null}
        </Button>
      ))}
    </nav>
  );
}

function AppScreen({
  bottomInset = false,
  children,
}: {
  bottomInset?: boolean;
  children: ReactNode;
}) {
  return (
    <div
      className={cn(
        "relative flex size-full flex-col",
        bottomInset && "pb-[4.9rem]"
      )}
    >
      {children}
    </div>
  );
}

function StatusBar({ time = "4:47" }: { time?: string }) {
  return (
    <div className="flex h-11 shrink-0 items-end justify-between px-6 pb-1.5 font-semibold text-xs">
      <span>{time}</span>
      <div aria-hidden="true" className="flex items-center gap-1.5">
        <span className="tracking-[-0.16em]">▮▮▮▮</span>
        <span>◔</span>
        <span className="rounded bg-foreground px-1 text-[0.6rem] text-background">
          46
        </span>
      </div>
    </div>
  );
}

function AppHeader({ action, title }: { action?: ReactNode; title: string }) {
  return (
    <header className="flex items-end justify-between gap-4 px-5 pt-3 pb-3">
      <h1 className="font-semibold text-[1.85rem] tracking-[-0.045em]">
        {title}
      </h1>
      {action}
    </header>
  );
}

function DetailHeader({
  action,
  onBack,
  title,
}: {
  action?: ReactNode;
  onBack: () => void;
  title: string;
}) {
  return (
    <header className="grid h-14 shrink-0 grid-cols-[2.5rem_1fr_2.5rem] items-center border-b px-3">
      <Button aria-label="Back" onClick={onBack} size="icon" variant="ghost">
        <ArrowLeftIcon />
      </Button>
      <h1 className="truncate text-center font-semibold text-sm">{title}</h1>
      <div className="flex justify-end">{action}</div>
    </header>
  );
}

function SettingsCard({
  children,
  description,
  title,
}: {
  children: ReactNode;
  description: string;
  title: string;
}) {
  return (
    <Card className="gap-3">
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col">{children}</CardContent>
    </Card>
  );
}

function ValueRow({
  disabled,
  icon: Icon,
  label,
  onClick,
  value,
}: {
  disabled?: boolean;
  icon?: typeof MicIcon;
  label: string;
  onClick?: () => void;
  value: string;
}) {
  return (
    <Button
      className="h-12 w-full justify-start rounded-none px-0 font-normal"
      disabled={disabled}
      onClick={onClick}
      variant="ghost"
    >
      {Icon ? <Icon data-icon="inline-start" /> : null}
      <span>{label}</span>
      <span className="ml-auto text-muted-foreground">{value}</span>
      <ChevronRightIcon data-icon="inline-end" />
    </Button>
  );
}

function ControlRow({
  children,
  icon: Icon,
  label,
}: {
  children: ReactNode;
  icon?: typeof MicIcon;
  label: string;
}) {
  return (
    <div className="flex min-h-12 items-center gap-2 text-sm">
      {Icon ? <Icon className="size-4 text-muted-foreground" /> : null}
      <span>{label}</span>
      <div className="ml-auto">{children}</div>
    </div>
  );
}

function InfoRow({
  label,
  value,
  valueClassName,
}: {
  label: string;
  value: string;
  valueClassName?: string;
}) {
  return (
    <div className="flex min-h-11 items-center justify-between gap-4 text-sm">
      <span className="text-muted-foreground">{label}</span>
      <span className={cn("text-right font-medium", valueClassName)}>
        {value}
      </span>
    </div>
  );
}
