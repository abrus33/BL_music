// Theme.js - 全局主题样式常量
// 使用 .pragma library 确保只加载一次
// 在 QML 中: import "Theme.js" as Theme → Theme.colors.accent
//
// 新人阅读重点：
// 1. 这里没有业务逻辑，只集中保存颜色、字号、间距、圆角、尺寸。
// 2. QML 页面通过 Theme.colors.xxx 读取，避免每个文件到处写硬编码颜色。
.pragma library

// 语义颜色。所有页面直接使用这些键，不保留旧名兼容层。
var colors = {
    transparent: "#00000000",
    accent: "#fb7299",
    canvas: "#151517",
    surface: "#1b1b1e",
    surfaceRaised: "#222226",
    surfaceHover: "#29292e",
    accentHover: "#ff8bad",
    accentPressed: "#dc5f84",
    accentChecked: "#3a2630",
    controlInset: "#121214",
    controlDisabled: "#2b2b30",
    drawerBackdrop: "#99000000",
    textPrimary: "#f5f5f7",
    textSecondary: "#c8c8ce",
    textTertiary: "#92929b",
    textDisabled: "#62626a",
    borderSoft: "#2b2b30",
    borderFocus: "#fb7299",
    error: "#ff7188",
    qrSurface: "#ffffff"
};

// 字号分组：页面大标题用 h1，普通正文用 body，辅助说明用 caption/small。
var fontSizes = {
    h1: 28,
    h2: 18,
    h3: 17,
    body: 15,
    bodySmall: 14,
    caption: 13,
    small: 12
};

// 间距分组：命名按使用场景区分，避免看到一堆没有语义的数字。
var spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 };

// 圆角分组：组件按用途取值，保持视觉一致。
var radius = { control: 8, card: 12, panel: 16, round: 999 };

var breakpoints = { compact: 860, expanded: 1180 };

var motion = { fast: 140, page: 200, drawer: 240 };

// 固定尺寸分组：主布局和常用控件尺寸集中放在这里。
var sizes = {
    playerHeight: 92,
    playerMediaExpandedWidth: 260,
    playerMediaMediumWidth: 190,
    playerProgressMinWidth: 180,
    playerVolumeWidth: 132,
    queueRowHeight: 56,
    coverSmall: 52,
    coverMedium: 48,
    navItemHeight: 40,
    btnHeight: 40,
    favoritesContentMinWidth: 320,
    favoritesContentMinHeight: 560,
    favoriteFolderCardHeight: 88,
    mediaRowHeight: 72,
    statePanelHeight: 220,
    loginAccountIcon: 32,
    loginLogoutButtonWidth: 120,
    loginModeButtonWidth: 140,
    loginInputMaxWidth: 560,
    loginInputTrailingPadding: 52,
    loginPrimaryButtonWidth: 160,
    loginSecondaryButtonWidth: 100,
    loginQrSkeletonMaxWidth: 320,
    loginQrFrameSize: 236,
    loginQrImageSize: 220,
    loginQrLabelInset: 24
};
