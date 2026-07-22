import { cn } from "@/lib/utils";
import type { PropsWithChildren } from "react";
import { ScrollView, type ScrollViewProps } from "react-native";

import { APP_LAYOUT } from "@/components/app/app-layout";

const APP_FORM_SHEET_CONTENT_STYLE = {
  gap: APP_LAYOUT.screenStackGap,
  paddingBottom: APP_LAYOUT.formSheetBottomInset,
  paddingHorizontal: APP_LAYOUT.screenGutter,
  paddingTop: APP_LAYOUT.formSheetTopInset,
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
      contentContainerClassName={contentClassName}
      contentContainerStyle={APP_FORM_SHEET_CONTENT_STYLE}
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
