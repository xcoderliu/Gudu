import RippleCore
import SwiftUI

private enum DashboardTab: String, CaseIterable {
    case today = "今日饮水"
    case settings = "提醒设置"
    case about = "关于澄水"

    var symbol: String {
        switch self {
        case .today: "square.grid.2x2"
        case .settings: "slider.horizontal.3"
        case .about: "leaf"
        }
    }
}

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @State private var tab = DashboardTab.today
    @State private var justRecorded = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Palette.line).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    switch tab {
                    case .today: today
                    case .settings: SettingsView(model: model)
                    case .about: about
                    }
                }
                .padding(.horizontal, 34).padding(.top, 48).padding(.bottom, 30)
                .frame(maxWidth: 1040, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Palette.background)
        }
        .frame(minWidth: 960, minHeight: 680)
        .font(.system(size: 13))
        .preferredColorScheme(.light)
        .alert("登录项设置", isPresented: Binding(get: { model.serviceError != nil }, set: { if !$0 { model.serviceError = nil } })) {
            Button("知道了", role: .cancel) { model.serviceError = nil }
        } message: { Text(model.serviceError ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 23)).foregroundStyle(Palette.accent)
                    .frame(width: 44, height: 46)
                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("澄水").font(.system(size: 22, weight: .semibold)).tracking(2)
                    Text("R I P P L E").font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.secondary)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 23).padding(.top, 56)
            Text("好好工作，也好好喝水。")
                .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                .padding(.leading, 25).padding(.top, 19).padding(.bottom, 35)
            VStack(spacing: 7) {
                ForEach(DashboardTab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).font(.system(size: 14)).frame(width: 19)
                            Text(item.rawValue).font(.system(size: 12, weight: tab == item ? .semibold : .regular))
                            Spacer()
                            if tab == item { Circle().fill(Palette.accent).frame(width: 5, height: 5) }
                        }
                        .foregroundStyle(tab == item ? Palette.ink : Palette.secondary)
                        .padding(.horizontal, 15).frame(height: 43)
                        .background(tab == item ? .white : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            Spacer(minLength: 100)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle().fill(model.settings.isEnabled ? Palette.accent : Palette.secondary)
                        .frame(width: 6, height: 6)
                    Text(model.settings.isEnabled ? "温柔提醒中" : "提醒已暂停")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.ink)
                }
                HStack(spacing: 7) {
                    Image(systemName: "display.2")
                    Text("已连接 \(model.displayCount) 块屏幕")
                }
                .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 3)
                HStack {
                    Text("留一点温柔给自己")
                    Spacer()
                    Text("v0.1.0").monospaced()
                }
                .font(.system(size: 9)).foregroundStyle(Palette.secondary.opacity(0.8))
            }
            .padding(.horizontal, 25).padding(.bottom, 26)
        }
        .frame(width: 200)
        .background(Palette.sidebar)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(tab == .today ? model.now.formatted(.dateTime.month(.twoDigits).day(.twoDigits).weekday(.wide).locale(Locale(identifier: "zh_CN"))) : "YOUR LITTLE DAILY RITUAL")
                    .font(.system(size: 10, weight: .medium)).tracking(1.1).foregroundStyle(Palette.secondary)
                Text(tab == .today ? "每一杯，都是对自己的照顾。" : tab == .settings ? "找到你的喝水节奏。" : "一杯水，一点点好状态。")
                    .font(.system(size: 23, weight: .semibold)).tracking(0.5).foregroundStyle(Palette.ink)
            }
            Spacer(minLength: 8)
            Button { model.preview() } label: {
                Label("预览动画", systemImage: "play.circle")
            }
            .buttonStyle(FilledButtonStyle(prominent: false))
            .keyboardShortcut("p", modifiers: .command)
            .help("在鼠标所在屏幕预览全屏矢量动画（⌘P）")
        }
    }

    private var today: some View {
        VStack(spacing: 18) {
            hero
            HStack(spacing: 13) {
                statistic(title: "今日饮水", value: "\(model.todayML)", suffix: "mL", symbol: "drop", detail: "每天，从一杯开始")
                statistic(title: "目标进度", value: "\(Int(model.progress * 100))", suffix: "%", symbol: "chart.bar", detail: "今日目标 \(model.settings.dailyGoalML) mL")
                statistic(title: "已喝杯数", value: "\(model.todayEntries.count)", suffix: "杯", symbol: "cup.and.saucer", detail: "每杯 \(model.settings.servingML) mL")
            }
            Card {
                VStack(alignment: .leading, spacing: 19) {
                    HStack {
                        SectionHeading(title: "今天的喝水节奏")
                        Spacer()
                        Button("调整提醒  ↗") { tab = .settings }
                            .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.accent)
                    }
                    HStack(spacing: 0) {
                        scheduleFact(symbol: "clock", title: "提醒间隔", value: "每 \(model.settings.intervalMinutes) 分钟")
                        Spacer()
                        scheduleFact(symbol: "sun.horizon", title: "每日时段", value: "\(clockText(model.settings.startMinute)) — \(clockText(model.settings.endMinute))")
                        Spacer()
                        scheduleFact(symbol: "display", title: "提醒屏幕", value: model.settings.displayMode == .cursor ? "跟随鼠标所在屏幕" : "所有屏幕同步")
                    }
                }
            }
            Card(padding: 20) {
                HStack(spacing: 12) {
                    Image(systemName: justRecorded ? "checkmark.circle.fill" : "leaf")
                        .font(.system(size: 20)).foregroundStyle(Palette.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(justRecorded ? "这一杯，记下了。" : model.todayEntries.isEmpty ? "今天的第一杯，随时可以开始。" : "小小的坚持，正在慢慢累积。")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink)
                        Text(model.todayEntries.last.map { "最近一杯：\($0.date.formatted(date: .omitted, time: .shortened)) · \($0.amountML) mL" } ?? "点一下「喝一杯」，记录此刻的小小补给。")
                            .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    if !model.todayEntries.isEmpty {
                        Button("撤销上一杯") { model.undoLastDrink(); justRecorded = false }
                            .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    }
                }
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22).fill(
                LinearGradient(colors: [Color(hex: 0x123E3D), Color(hex: 0x205C51)], startPoint: .topLeading, endPoint: .bottomTrailing))
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 7) {
                        Circle().fill(Palette.mint).frame(width: 5, height: 5)
                        Text(model.settings.isEnabled ? "YOUR NEXT SIP" : "TAKE YOUR TIME")
                            .font(.system(size: 9, weight: .semibold)).tracking(2)
                    }
                    .foregroundStyle(Palette.mint.opacity(0.7))
                    Text(model.countdown)
                        .font(.system(size: model.countdown.count > 5 ? 42 : 54, weight: .light, design: .rounded))
                        .monospacedDigit().foregroundStyle(Color(hex: 0xEFF7E9))
                        .padding(.top, 15)
                        .contentTransition(.numericText())
                    Text(model.statusText)
                        .font(.system(size: 11)).foregroundStyle(Palette.mint.opacity(0.55))
                        .padding(.top, 7)
                    HStack(spacing: 11) {
                        Button {
                            model.recordDrink()
                            justRecorded = true
                        } label: {
                            Label("喝一杯  +\(model.settings.servingML) mL", systemImage: "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 18).frame(height: 39)
                                .foregroundStyle(Palette.ocean)
                                .background(Palette.mint, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("d", modifiers: .command)
                        Button { model.toggleEnabled() } label: {
                            Image(systemName: model.settings.isEnabled ? "pause" : "play")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 39, height: 39)
                                .foregroundStyle(Palette.mint)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.mint.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help(model.settings.isEnabled ? "暂停提醒" : "继续提醒")
                        .accessibilityLabel(model.settings.isEnabled ? "暂停提醒" : "继续提醒")
                    }
                    .padding(.top, 24)
                }
                .padding(.leading, 30)
                Spacer(minLength: 0)
                WaterScene(framesPerSecond: 24).frame(width: 270, height: 270).padding(.trailing, 6)
            }
        }
        .frame(height: 270)
    }

    private func statistic(title: String, value: String, suffix: String, symbol: String, detail: String) -> some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    Spacer()
                    Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(Palette.accent.opacity(0.6))
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value).font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
                    Text(suffix).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                .foregroundStyle(Palette.ink)
                Text(detail).font(.system(size: 9)).foregroundStyle(Palette.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func scheduleFact(symbol: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(Palette.accent.opacity(0.75)).padding(.top, 2)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                Text(value).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.ink)
            }
        }
    }

    private var about: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Palette.ocean)
                HStack(spacing: 15) {
                    WaterScene(framesPerSecond: 24).frame(width: 270, height: 270)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("澄水 · Ripple").font(.system(size: 28, weight: .light)).foregroundStyle(Palette.mint)
                        Text("给忙碌留一口水，\n给自己留一点温柔。")
                            .font(.system(size: 15)).lineSpacing(8).foregroundStyle(Palette.mint.opacity(0.65))
                        Text("VERSION 0.1.0").font(.system(size: 9)).tracking(2).foregroundStyle(Palette.mint.opacity(0.4))
                    }
                    Spacer()
                }
            }
            .frame(height: 270)
            Card {
                VStack(alignment: .leading, spacing: 22) {
                    SectionHeading(title: "简单一点，刚刚好。")
                    aboutFact("network.slash", "完全离线", "无需账号，也没有广告与追踪。")
                    aboutFact("lock.shield", "只留在本机", "提醒偏好与最近 90 天饮水记录保存在这台 Mac。")
                    aboutFact("camera", "可选摄像头识别", "仅在强制检测或识别测试时使用，不保存或上传画面。")
                    aboutFact("sparkles", "温柔的提醒", "自适应矢量动画；开启系统「减少动态效果」时静态呈现。")
                    aboutFact("heart", "按自己的节奏", "饮水目标由你决定。关闭窗口后，菜单栏里的小水滴会继续陪伴。")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func aboutFact(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(Palette.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink)
                Text(detail).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
        }
    }
}
