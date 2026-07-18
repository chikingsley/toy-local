import { cn } from "@/lib/utils";
import type { PropsWithChildren } from "react";
import { ScrollView, type ScrollViewProps } from "react-native";

const APP_FORM_SHEET_CONTENT_STYLE = {
  gap: 10,
  paddingBottom: 40,
  paddingHorizontal: 18,
  paddingTop: 24,
} as const;

const APP_FORM_SHEET_INSET_PROPS = {
  automaticallyAdjustContentInsets: true,
  contentInsetAdjustmentBehavior: "automatic" as const,
  automaticallyAdjustsScrollIndicatorInsets: true,
};

type AppFormSheetScrollProps = PropsWithChildren<
  Omit<ScrollViewProps, "contentInsetAdjustmentBehavior"> & {
    contentClassName?: string;
  }
>;

function AppFormSheetScroll({
  children,
  className,
  contentClassName,
  ...props
}: AppFormSheetScrollProps) {
  return (
    <ScrollView
      {...APP_FORM_SHEET_INSET_PROPS}
      className={cn("bg-background flex-1", className)}
      contentContainerClassName={cn(
        "gap-3 px-[18px] pt-6 pb-10",
        contentClassName,
      )}
      {...props}
    >
      {children}
    </ScrollView>
  );
}

export {
  APP_FORM_SHEET_CONTENT_STYLE,
  APP_FORM_SHEET_INSET_PROPS,
  AppFormSheetScroll,
};
