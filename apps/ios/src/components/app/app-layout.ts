const APP_LAYOUT = {
  bottomActionExtraInset: 20,
  bottomActionTopInset: 12,
  cardContentInset: 17,
  denseListGap: 8,
  formSheetBottomInset: 40,
  formSheetTopInset: 24,
  minimumControlSize: 44,
  screenBottomInset: 120,
  screenGutter: 18,
  screenStackGap: 12,
  screenTopInset: 18,
} as const;

const APP_SCROLL_CONTENT_STYLE = {
  gap: APP_LAYOUT.screenStackGap,
  paddingBottom: APP_LAYOUT.screenBottomInset,
  paddingHorizontal: APP_LAYOUT.screenGutter,
  paddingTop: APP_LAYOUT.screenTopInset,
} as const;

const APP_VIRTUALIZED_LIST_CONTENT_STYLE = APP_SCROLL_CONTENT_STYLE;

const APP_LIST_WITH_BOTTOM_ACTION_CONTENT_STYLE = {
  gap: APP_LAYOUT.screenStackGap,
  paddingBottom: APP_LAYOUT.screenTopInset,
  paddingHorizontal: APP_LAYOUT.screenGutter,
  paddingTop: APP_LAYOUT.screenTopInset,
} as const;

export {
  APP_LAYOUT,
  APP_LIST_WITH_BOTTOM_ACTION_CONTENT_STYLE,
  APP_SCROLL_CONTENT_STYLE,
  APP_VIRTUALIZED_LIST_CONTENT_STYLE,
};
