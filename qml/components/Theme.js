// Theme.js - 全局主题样式常量
// 使用 .pragma library 确保只加载一次
// 在 QML 中: import "Theme.js" as Theme → Theme.colors.accent
//
// 新人阅读重点：
// 1. 这里没有业务逻辑，只集中保存颜色、字号、间距、圆角、尺寸。
// 2. QML 页面通过 Theme.colors.xxx 读取，避免每个文件到处写硬编码颜色。
.pragma library

// 颜色分组：bg* 是背景，text* 是文字，border* 是边框/分隔线。
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
var spacing = {
    page: 24,
    card: 20,
    section: 16,
    item: 12,
    compact: 8,
    tight: 4
};

// 圆角分组：组件按用途取值，保持视觉一致。
var radius = {
    card: 12,
    button: 8,
    input: 8,
    cover: 8,
    small: 6,
    pill: 20
};

// 固定尺寸分组：主布局和常用控件尺寸集中放在这里。
var sizes = {
    sidebarWidth: 240,
    playerHeight: 92,
    coverSmall: 52,
    coverMedium: 76,
    navItemHeight: 40,
    btnHeight: 40
};

// 动画时长分组：hover、颜色变化等轻量动画使用。
var duration = {
    fast: 120,
    normal: 200,
    slow: 350
};
