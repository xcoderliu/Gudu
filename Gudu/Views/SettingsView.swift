import GuduCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            Card {
                SettingsRow(title: "喝水提醒", detail: "关闭主窗口后，提醒仍会在菜单栏继续运行。") {
                    Toggle("启用提醒", isOn: Binding(get: { model.settings.isEnabled }, set: { _ in model.toggleEnabled() }))
                        .labelsHidden().toggleStyle(.switch).tint(Palette.accent)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 23) {
                    SectionHeading(title: "属于你的节奏", subtitle: "设置自动保存；调整间隔、日期或时段后重新计时。")
                    HStack {
                        Text("每隔多久提醒").foregroundStyle(Palette.ink)
                        Spacer()
                        Stepper(value: $model.settings.intervalMinutes, in: 1...240) {
                            Text("\(model.settings.intervalMinutes) 分钟")
                                .monospacedDigit().fontWeight(.medium).frame(width: 70, alignment: .trailing)
                        }
                        .fixedSize()
                        .accessibilityLabel("提醒间隔，分钟")
                    }
                    HStack(spacing: 9) {
                        ForEach([15, 30, 45, 60, 90], id: \.self) { value in
                            Button { model.settings.intervalMinutes = value } label: {
                                Text("\(value) 分钟").font(.system(size: 11, weight: .medium))
                                    .frame(maxWidth: .infinity).frame(height: 35)
                                    .foregroundStyle(model.settings.intervalMinutes == value ? Palette.accent : Palette.secondary)
                                    .background(model.settings.intervalMinutes == value ? Palette.mint.opacity(0.35) : Palette.background,
                                                in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8)
                                        .stroke(model.settings.intervalMinutes == value ? Palette.accent.opacity(0.25) : .clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Divider().overlay(Palette.line)
                    SettingsRow(title: "提前接水", detail: "先装满杯子，喝水时就不用临时找水啦。") {
                        Picker("提前接水", selection: $model.settings.preparationLeadMinutes) {
                            Text("关闭").tag(0)
                            ForEach([3, 5, 10], id: \.self) { minutes in
                                Text("提前 \(minutes) 分钟").tag(minutes)
                            }
                        }.labelsHidden().frame(width: 125)
                    }
                    HStack(alignment: .top, spacing: 16) {
                        Text(model.settings.preparationLeadMinutes > 0 && model.settings.intervalMinutes <= model.settings.preparationLeadMinutes
                             ? "提醒间隔不长于提前时间，本轮不显示接水气泡。"
                             : model.settings.preparationLeadMinutes == 0
                             ? "已关闭接水提醒，喝水提醒仍会照常出现。"
                             : "小气泡停留 15 秒，不响铃、不打断工作；调整不重置喝水倒计时。")
                            .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("预览气泡") { model.previewPreparation() }
                            .disabled(model.settings.preparationLeadMinutes == 0 || model.isPresenting)
                    }
                    Divider().overlay(Palette.line)
                    weekdayPicker
                    Divider().overlay(Palette.line)
                    HStack(spacing: 24) {
                        timePicker("开始时间", minute: $model.settings.startMinute)
                        Image(systemName: "arrow.right").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        timePicker("结束时间", minute: $model.settings.endMinute)
                        Spacer()
                    }
                    Label(timeDescription, systemImage: "moon.zzz")
                        .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeading(title: "让提醒出现在对的地方", subtitle: "根据提醒出现那一刻的鼠标位置选择屏幕。")
                    HStack(spacing: 12) {
                        displayOption(.cursor, symbol: "cursorarrow.motionlines", title: "工作屏幕", detail: "跟随鼠标所在的屏幕")
                        displayOption(.all, symbol: "display.2", title: "所有屏幕", detail: "在每块屏幕同步播放动画")
                    }
                    Text("无法确定鼠标位置时，会自动在所有屏幕提醒。")
                        .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 21) {
                    SectionHeading(title: "杯子到嘴边，再继续", subtitle: "实验功能：检测杯子靠近嘴边，不判断是否真正吞咽。")
                    SettingsRow(title: "强制检测喝水", detail: "提醒时使用摄像头；累计有效杯具线索后完成，遮挡时确认会慢一些。") {
                        Toggle("强制检测喝水", isOn: $model.settings.requireDrinkVerification)
                            .labelsHidden().toggleStyle(.switch).tint(Palette.accent)
                    }
                    Text("画面仅在本机分析，不保存、不上传。摄像头检测期间不自动退场，识别完成后记一杯；未授权或摄像头不可用时，可手动确认。")
                        .font(.system(size: 10)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                    Button { model.testDrinkVerification() } label: {
                        Label("测试摄像头识别（不记水）", systemImage: "camera")
                    }.buttonStyle(FilledButtonStyle(prominent: false))
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 21) {
                    SectionHeading(title: "再加一点贴心")
                    SettingsRow(title: "自动退场", detail: model.settings.requireDrinkVerification ? "摄像头检测期间不自动关闭；关闭检测后恢复之前的退场设置。" : "自动关闭不会记录饮水；按 Esc 也可以随时关闭。") {
                        Picker("自动退场", selection: autoDismissSelection) {
                            Text("15 秒").tag(15)
                            Text("30 秒").tag(30)
                            Text("60 秒").tag(60)
                            Text("不自动关闭").tag(0)
                        }
                        .labelsHidden().frame(width: 125).disabled(model.settings.requireDrinkVerification)
                    }
                    Divider()
                    SettingsRow(title: "喝水音效", detail: "跟随动画播放接水、咕嘟喝水与轻轻舒气的声音。") {
                        Toggle("喝水音效", isOn: $model.settings.soundEnabled)
                            .labelsHidden().toggleStyle(.switch).tint(Palette.accent)
                    }
                    Divider()
                    SettingsRow(title: "登录时打开", detail: "每次启动 Mac，让咕嘟自动在菜单栏陪伴。") {
                        Toggle("登录时打开", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                            .labelsHidden().toggleStyle(.switch).tint(Palette.accent)
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 21) {
                    SectionHeading(title: "每一杯，都算数", subtitle: "这里的目标只是个人习惯记录，可以按自己的需要调整。")
                    SettingsRow(title: "每杯容量", detail: "点击「喝一杯」时记录的水量。") {
                        Stepper(value: $model.settings.servingML, in: 50...1000, step: 50) {
                            Text("\(model.settings.servingML) mL").monospacedDigit().frame(width: 72, alignment: .trailing)
                        }.fixedSize().accessibilityLabel("每杯容量，毫升")
                    }
                    Divider()
                    SettingsRow(title: "每日目标", detail: "新的一天会自动重新统计。") {
                        Stepper(value: $model.settings.dailyGoalML, in: 500...5000, step: 250) {
                            Text("\(model.settings.dailyGoalML) mL").monospacedDigit().frame(width: 72, alignment: .trailing)
                        }.fixedSize().accessibilityLabel("每日目标，毫升")
                    }
                }
            }
        }
        .foregroundStyle(Palette.ink)
    }

    private var autoDismissSelection: Binding<Int> {
        Binding(get: {
            model.settings.requireDrinkVerification ? 0 : model.settings.autoDismissSeconds
        }, set: { seconds in
            guard !model.settings.requireDrinkVerification else { return }
            model.settings.autoDismissSeconds = seconds
        })
    }

    private var timeDescription: String {
        if model.settings.startMinute == model.settings.endMinute { return "开始和结束相同：所选日期全天提醒。" }
        if model.settings.startMinute > model.settings.endMinute { return "跨午夜按开始当天计算，持续到次日结束时间。" }
        return "只在这个时段提醒，其余时间保持安静。"
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Text("每周提醒日").font(.system(size: 12, weight: .medium))
                Spacer()
                weekdayPreset("周一至周五", days: ReminderWeekday.workdays)
                weekdayPreset("周末", days: ReminderWeekday.weekend)
                weekdayPreset("每天", days: ReminderWeekday.everyDay)
            }
            HStack(spacing: 8) {
                ForEach(ReminderWeekday.allCases) { day in
                    let selected = model.settings.weekdays.contains(day)
                    Button {
                        var days = model.settings.weekdays
                        if selected { days.remove(day) } else { days.insert(day) }
                        model.settings.weekdays = days
                    } label: {
                        Text(AppModel.weekdayLabel(day)).font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity).frame(height: 35)
                            .foregroundStyle(selected ? Palette.accent : Palette.secondary)
                            .background(selected ? Palette.mint.opacity(0.35) : Palette.background,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Palette.accent.opacity(0.25) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(AppModel.weekdayLabel(day))提醒")
                    .accessibilityValue(selected ? "已选择" : "未选择")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            Text(model.settings.weekdays.isEmpty ? "未选择日期，自动提醒暂停；仍可手动记录和预览。" : "仅在勾选的日期与下方时段自动提醒。")
                .font(.system(size: 10)).foregroundStyle(model.settings.weekdays.isEmpty ? Color.orange : Palette.secondary)
        }
    }

    private func weekdayPreset(_ title: String, days: Set<ReminderWeekday>) -> some View {
        Button(title) { model.settings.weekdays = days }
            .buttonStyle(.plain).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.accent)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(model.settings.weekdays == days ? Palette.mint.opacity(0.35) : Palette.background, in: Capsule())
    }

    private func timePicker(_ label: String, minute: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            DatePicker(label, selection: Binding(
                get: {
                    Calendar.current.date(bySettingHour: minute.wrappedValue / 60,
                                          minute: minute.wrappedValue % 60, second: 0, of: model.now) ?? model.now
                },
                set: {
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                    minute.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                }
            ), displayedComponents: [.hourAndMinute])
            .labelsHidden().datePickerStyle(.field).environment(\.locale, Locale(identifier: "zh_CN"))
            .controlSize(.large).fixedSize()
            .accessibilityLabel(label)
        }
    }

    private func displayOption(_ mode: DisplayMode, symbol: String, title: String, detail: String) -> some View {
        Button { model.settings.displayMode = mode } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 20)).frame(width: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 12, weight: .semibold))
                    Text(detail).font(.system(size: 9)).foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: model.settings.displayMode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16)).foregroundStyle(model.settings.displayMode == mode ? Palette.accent : Palette.line)
            }
            .padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Palette.ink)
            .background(model.settings.displayMode == mode ? Palette.mint.opacity(0.16) : Palette.background,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(model.settings.displayMode == mode ? Palette.accent.opacity(0.4) : Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.settings.displayMode == mode ? [.isSelected] : [])
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 10)
            control
        }
    }
}
