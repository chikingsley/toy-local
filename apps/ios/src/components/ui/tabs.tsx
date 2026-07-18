import { TextClassContext } from "@/components/ui/text";
import { cn } from "@/lib/utils";
import * as TabsPrimitive from "@rn-primitives/tabs";
import { Platform } from "react-native";

function Tabs({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Root>) {
  return (
    <TabsPrimitive.Root
      className={cn("flex flex-col gap-2", className)}
      {...props}
    />
  );
}

function TabsList({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.List>) {
  return (
    <TabsPrimitive.List
      className={cn(
        "bg-muted flex h-10 flex-row items-center justify-center rounded-xl p-[3px]",
        Platform.select({ web: "inline-flex w-fit", native: "w-full" }),
        className,
      )}
      {...props}
    />
  );
}

function TabsTrigger({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Trigger>) {
  const { value } = TabsPrimitive.useRootContext();
  const selected = props.value === value;
  return (
    <TextClassContext.Provider
      value={cn(
        "text-muted-foreground text-sm font-semibold",
        selected && "text-foreground",
      )}
    >
      <TabsPrimitive.Trigger
        className={cn(
          "flex h-full flex-1 flex-row items-center justify-center gap-1.5 rounded-lg border border-transparent px-2 py-1 shadow-none",
          props.disabled && "opacity-50",
          selected && "bg-background border-border",
          className,
        )}
        {...props}
      />
    </TextClassContext.Provider>
  );
}

function TabsContent({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Content>) {
  return (
    <TabsPrimitive.Content className={cn("flex-1", className)} {...props} />
  );
}

export { Tabs, TabsContent, TabsList, TabsTrigger };
