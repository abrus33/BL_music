// Theme.js - 全局主题样式常量
// 使用 .pragma library 确保只加载一次
// 在 QML 中: import "Theme.js" as Theme → Theme.colors.accent
.pragma library

var colors = {
    accent: "#fb7299",
    bgApp: "#181818",
    bgSidebar: "#111111",
    bgContent: "#202020",
    bgCard: "#262626",
    bgCardHover: "#2d2d2d",
    bgPlayer: "#141414",
    bgInput: "#1a1a1a",
    bgPlaceholder: "#2a2a2a",
    textPrimary: "#ffffff",
    textSecondary: "#f5f5f5",
    textTertiary: "#bcbcbc",
    textMuted: "#9d9d9d",
    textDim: "#7d7d7d",
    borderPlayer: "#292929",
    borderInput: "#3a3a3a",
    error: "#fb7299"
};

var fontSizes = {
    h1: 28,
    h2: 18,
    h3: 17,
    body: 15,
    bodySmall: 14,
    caption: 13,
    small: 12
};

var spacing = {
    page: 24,
    card: 20,
    section: 16,
    item: 12,
    compact: 8,
    tight: 4
};

var radius = {
    card: 12,
    button: 8,
    input: 8,
    cover: 8,
    small: 6,
    pill: 20
};

var sizes = {
    sidebarWidth: 240,
    playerHeight: 92,
    coverSmall: 52,
    coverMedium: 76,
    navItemHeight: 40,
    btnHeight: 40
};

var duration = {
    fast: 120,
    normal: 200,
    slow: 350
};
