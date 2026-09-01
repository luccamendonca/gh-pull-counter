import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: PRCounterModel
    @AppStorage(PRCounterModel.intervalKey) private var intervalMinutes = PRCounterModel.defaultIntervalMinutes

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(model.weekRange.title)
                    .font(.headline)
                Text("Open · Draft · Merged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let counts = model.counts {
                VStack(spacing: 8) {
                    MetricRow(symbol: "arrow.up.circle", tint: .blue, label: "Opened", value: counts.opened)
                    MetricRow(symbol: "square.and.pencil", tint: .orange, label: "Drafts", value: counts.drafts)
                    MetricRow(symbol: "arrow.triangle.merge", tint: .purple, label: "Merged", value: counts.merged)
                }
            } else if let error = model.error {
                ErrorPane(error: error, isAuth: model.isAuthError, retry: model.refreshNow)
            } else {
                ProgressView()
                    .padding(.vertical, 14)
            }

            if model.counts != nil {
                HStack(spacing: 6) {
                    if let updated = model.lastUpdated {
                        Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if model.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    if model.error != nil {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .help(model.error?.errorDescription ?? "")
                    }
                }
            }

            Divider()

            Picker("Refresh every", selection: intervalBinding) {
                Text("5 m").tag(5)
                Text("15 m").tag(15)
                Text("30 m").tag(30)
                Text("1 h").tag(60)
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    model.refreshNow()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh now")
                .disabled(model.isLoading)

                Button("GitHub") {
                    NSWorkspace.shared.open(model.githubSearchURL)
                }
                .help("Open this week's search on GitHub")

                if let login = model.login {
                    Text("@\(login)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 290)
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { intervalMinutes },
            set: { newValue in
                intervalMinutes = newValue
                model.restartPolling()
            }
        )
    }
}

private struct MetricRow: View {
    let symbol: String
    let tint: Color
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
    }
}

private struct ErrorPane: View {
    let error: FetchError
    let isAuth: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(error.errorDescription ?? "Something went wrong")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if isAuth {
                HStack(spacing: 6) {
                    Text("gh auth login")
                        .font(.system(.callout, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("gh auth login", forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .help("Copy command")
                }
            }
            Button("Retry", action: retry)
        }
        .padding(.vertical, 6)
    }
}
