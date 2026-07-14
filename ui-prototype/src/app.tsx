import { ChevronLeftIcon, ChevronRightIcon } from "lucide-react";
import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { TimberVoxApp } from "@/features/mobile/timbervox-app";

interface ReferenceScreen {
  id: string;
  image: string;
  label: string;
}

const referenceScreens: ReferenceScreen[] = [
  { id: "home", image: "IMG_4097.PNG", label: "Home" },
  { id: "home-menu", image: "IMG_4098.PNG", label: "Mode menu" },
  { id: "settings", image: "IMG_4099.PNG", label: "Settings" },
  { id: "configuration", image: "IMG_4100.PNG", label: "Configuration" },
  { id: "keyboard", image: "IMG_4101.PNG", label: "Keyboard" },
  { id: "stats-empty", image: "IMG_4102.PNG", label: "Stats" },
  { id: "stats", image: "IMG_4106.JPG", label: "Stats filled" },
  { id: "modes", image: "IMG_4107.PNG", label: "Modes" },
  { id: "mode", image: "IMG_4108.PNG", label: "Mode" },
  { id: "models", image: "IMG_4109.PNG", label: "Models" },
  { id: "playback", image: "IMG_4110.PNG", label: "Playback" },
  { id: "realtime-info", image: "IMG_4111.PNG", label: "Realtime info" },
  { id: "shortcut-info", image: "IMG_4112.PNG", label: "Shortcut info" },
  { id: "presets", image: "IMG_4113.PNG", label: "Presets" },
  { id: "languages", image: "IMG_4114.PNG", label: "Languages" },
  { id: "mode-editor", image: "IMG_4115.PNG", label: "Mode editor" },
  { id: "license", image: "IMG_4116.PNG", label: "License" },
  { id: "license-menu", image: "IMG_4117.PNG", label: "License menu" },
  { id: "history", image: "IMG_4118.PNG", label: "History" },
  { id: "history-search", image: "IMG_4119.PNG", label: "History search" },
  { id: "history-detail", image: "IMG_4120.PNG", label: "History detail" },
  { id: "history-info", image: "IMG_4121.PNG", label: "Recording info" },
  { id: "reprocess", image: "IMG_4122.PNG", label: "Reprocess" },
  { id: "share", image: "IMG_4123.PNG", label: "Share" },
];

function App() {
  const [activeReference, setActiveReference] = useState("home");
  const activeIndex = referenceScreens.findIndex(
    (reference) => reference.id === activeReference
  );
  const activeScreen = useMemo(
    () => referenceScreens[activeIndex] ?? referenceScreens[0],
    [activeIndex]
  );

  const stepReference = (offset: number) => {
    const next =
      (activeIndex + offset + referenceScreens.length) %
      referenceScreens.length;
    setActiveReference(referenceScreens[next].id);
  };

  return (
    <main className="min-h-dvh bg-background text-foreground">
      <Tabs className="min-h-dvh gap-0" defaultValue="reference">
        <header className="sticky top-0 z-30 border-b bg-background/90 backdrop-blur-xl">
          <div className="mx-auto flex min-h-16 max-w-6xl items-center justify-between gap-4 px-4">
            <div className="hidden items-center gap-2 sm:flex">
              <VoxGlyph />
              <span className="font-semibold tracking-tight">TimberVox</span>
            </div>
            <TabsList className="h-10 flex-1 rounded-full sm:flex-none">
              <TabsTrigger className="rounded-full px-5" value="reference">
                Reference
              </TabsTrigger>
              <TabsTrigger className="rounded-full px-5" value="timbervox">
                TimberVox
              </TabsTrigger>
            </TabsList>
            <span className="hidden text-muted-foreground text-xs sm:block">
              iPhone prototype
            </span>
          </div>
        </header>

        <TabsContent className="m-0" value="reference">
          <section className="mx-auto flex max-w-6xl flex-col items-center gap-5 px-3 py-5 sm:px-6">
            <div className="flex w-full max-w-4xl items-center gap-2">
              <Button
                aria-label="Previous reference screen"
                onClick={() => stepReference(-1)}
                size="icon"
                variant="ghost"
              >
                <ChevronLeftIcon />
              </Button>
              <div className="min-w-0 flex-1 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
                <ToggleGroup
                  aria-label="Reference screens"
                  className="w-max"
                  onValueChange={(value) => {
                    const [nextValue] = value;
                    if (nextValue) {
                      setActiveReference(nextValue);
                    }
                  }}
                  value={[activeReference]}
                >
                  {referenceScreens.map((item) => (
                    <ToggleGroupItem
                      className="rounded-full px-3"
                      key={item.id}
                      value={item.id}
                    >
                      {item.label}
                    </ToggleGroupItem>
                  ))}
                </ToggleGroup>
              </div>
              <Button
                aria-label="Next reference screen"
                onClick={() => stepReference(1)}
                size="icon"
                variant="ghost"
              >
                <ChevronRightIcon />
              </Button>
            </div>

            <div className="iphone-canvas">
              <img
                alt={`Superwhisper reference screen: ${activeScreen.label}`}
                className="size-full object-cover"
                height={2048}
                src={`/reference/${activeScreen.image}`}
                width={946}
              />
            </div>
          </section>
        </TabsContent>

        <TabsContent className="m-0" value="timbervox">
          <section className="flex min-h-[calc(100dvh-4rem)] items-start justify-center px-3 py-5 sm:px-6">
            <div className="iphone-canvas">
              <TimberVoxApp />
            </div>
          </section>
        </TabsContent>
      </Tabs>
    </main>
  );
}

function VoxGlyph() {
  const bars = [
    { height: 8, id: "left-outer" },
    { height: 15, id: "left-inner" },
    { height: 22, id: "center" },
    { height: 15, id: "right-inner" },
    { height: 8, id: "right-outer" },
  ];

  return (
    <span aria-hidden="true" className="flex h-6 items-center gap-0.5">
      {bars.map((bar) => (
        <i
          className="w-0.5 rounded-full bg-primary"
          key={bar.id}
          style={{ height: bar.height }}
        />
      ))}
    </span>
  );
}

export default App;
