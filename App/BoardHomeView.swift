import SwiftUI

/// The configured home screen mirrors the reference at the iPad's native
/// 1366 x 1024 landscape canvas: three actions at the upper right, a wide
/// practice line, the centered page identity, and a ten-column keyboard tray.
struct BoardHomeView: View {
    @StateObject private var store = PageStore()
    @State private var editing = false
    @State private var selected: Int?
    @State private var confirmingDelete = false
    @State private var practiceText = ""
    @State private var typing = false
    @State private var showingSetup = false
    @State private var showingOnboarding = false
    @AppStorage("onboardingSeen") private var onboardingSeen = false

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                actions
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 44)
                    .padding(.trailing, max(36, proxy.size.width * 0.085))

                practiceField
                    .padding(.horizontal, max(48, proxy.size.width * 0.096))
                    .padding(.top, 24)

                pageIdentity
                    .padding(.top, 31)

                Spacer(minLength: 10)

                if !typing {
                    board
                        .frame(height: BoardMetrics.height(for: proxy.size.width))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert("Are you sure you want to delete?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteCurrentPage(); selected = nil }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the keyboard page along with all its contents or buttons.")
        }
        .sheet(isPresented: $showingSetup) { SetupView() }
        .fullScreenCover(isPresented: $showingOnboarding) { OnboardingView() }
        .onAppear {
            guard !onboardingSeen,
                  !ProcessInfo.processInfo.arguments.contains("-skipOnboarding") else { return }
            onboardingSeen = true
            showingOnboarding = true
        }
    }

    private var actions: some View {
        HStack(alignment: .top, spacing: 12) {
            ActionCard(title: "Delete Page", systemImage: "trash",
                       tint: Color(.systemGray2), enabled: store.canDeleteCurrentPage) {
                confirmingDelete = true
            }
            ActionCard(title: "Add New Page", systemImage: "plus",
                       tint: Color(.systemGray2)) {
                store.addPage()
                editing = true
            }
            ActionCard(title: "Edit Page", systemImage: "square.and.pencil",
                       tint: .accentColor, filled: true,
                       enabled: store.canEditCurrentPage) {
                editing.toggle()
                if !editing { selected = nil }
            }
        }
    }

    private var practiceField: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlainTextView(text: $practiceText,
                          placeholder: "I like to drink coffee",
                          minHeight: 50,
                          font: .systemFont(ofSize: 31, weight: .regular),
                          onFocusChange: { typing = $0 })
            Rectangle()
                .fill(Color(red: 1.0, green: 0.76, blue: 0.0))
                .frame(height: 3)
        }
    }

    @ViewBuilder
    private var pageIdentity: some View {
        if editing {
            VStack(spacing: 4) {
                Text("Name of Page")
                    .font(.system(size: 23))
                    .foregroundStyle(Color(.systemGray3))
                TextField("Name of Page", text: $store.currentName)
                    .font(.system(size: 24, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(width: 360)
            }
        } else {
            Menu {
                ForEach(store.pages) { page in
                    Button {
                        store.go(to: page.id)
                        selected = nil
                    } label: {
                        Label(page.name,
                              systemImage: page.id == store.currentPageID
                                  ? "checkmark" : "square.grid.2x2")
                    }
                }
                Divider()
                Button("Setup", systemImage: "gearshape") { showingSetup = true }
            } label: {
                VStack(spacing: 4) {
                    Text("Name of Page")
                        .font(.system(size: 23))
                        .foregroundStyle(Color(.systemGray3))
                    Text(store.currentName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Name of Page, \(store.currentName)")
        }
    }

    // MARK: - Ten-column board

    private var board: some View {
        GeometryReader { proxy in
            let metrics = BoardMetrics(size: proxy.size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.16), radius: 8, y: -2)

                ForEach(0..<KeyboardPage.rows, id: \.self) { row in
                    leftControl(row: row)
                        .frame(width: metrics.cell, height: metrics.cell)
                        .position(metrics.center(column: 0, row: row))
                }

                ForEach(0..<KeyboardPage.rows, id: \.self) { row in
                    ForEach(0..<KeyboardPage.columns, id: \.self) { column in
                        cell(row: row, column: column)
                            .frame(width: metrics.cell, height: metrics.cell)
                            .position(metrics.center(column: column + 1, row: row))
                    }
                }

                ControlKey(label: "ABC", tint: Color(.systemGray5), accessibilityName: "ABC")
                    .frame(width: metrics.cell, height: metrics.cell)
                    .position(metrics.center(column: 9, row: 0))

                ControlKey(label: "Enter", tint: Color(.systemGray3), accessibilityName: "Enter")
                    .frame(width: metrics.cell,
                           height: metrics.cell * 2 + metrics.spacing)
                    .position(metrics.center(column: 9, row: 1, rowSpan: 2))

                ControlKey(label: "sf:keyboard.chevron.compact.down",
                           tint: Color(.systemGray5), accessibilityName: "Hide keyboard")
                    .frame(width: metrics.cell, height: metrics.cell)
                    .position(metrics.center(column: 9, row: 3))
            }
        }
    }

    @ViewBuilder
    private func leftControl(row: Int) -> some View {
        switch row {
        case 0:
            ControlKey(label: "sf:house.fill", tint: Color(.systemGray5),
                       accessibilityName: "Home") { store.goHome() }
        case 1:
            ControlKey(label: "sf:square.grid.2x2.fill", tint: Color(.systemGray5),
                       accessibilityName: "Categories") { store.go(to: "Core") }
        case 2:
            ControlKey(label: "Clear", tint: Color(.systemGray5), accessibilityName: "Clear")
        default:
            ControlKey(label: "Delete\nword", tint: Color(.systemGray5),
                       accessibilityName: "Delete word")
        }
    }

    @ViewBuilder
    private func cell(row: Int, column: Int) -> some View {
        let index = row * KeyboardPage.columns + column
        if let fixed = PageStore.fixedControl(row: row, column: column) {
            ControlKey(label: fixed, tint: PageStore.tint(for: fixed),
                       accessibilityName: fixed == "sf:arrow.left" ? "Left" : "Right")
        } else {
            ButtonKey(button: store.button(at: index),
                      editing: editing,
                      isSelected: selected == index) {
                if editing {
                    selected = selected == index ? nil : index
                } else if let destination = store.button(at: index)?.destination {
                    store.go(to: destination)
                }
            }
            .popover(isPresented: Binding(
                get: { selected == index },
                set: { if !$0, selected == index { selected = nil } })) {
                    ButtonEditor(button: store.binding(at: index),
                                 pages: store.pages,
                                 currentPageID: store.currentPageID) {
                        selected = nil
                    }
                    .frame(minWidth: 380, minHeight: 460)
                }
        }
    }
}

private struct BoardMetrics {
    static let spacing: CGFloat = 8
    static let inset: CGFloat = 12
    static let aspectRatio: CGFloat = 1366 / 556

    let spacing = Self.spacing
    let inset = Self.inset
    let cell: CGFloat

    init(size: CGSize) {
        cell = (size.width - Self.inset * 2 - Self.spacing * 9) / 10
    }

    static func height(for width: CGFloat) -> CGFloat {
        width / aspectRatio
    }

    func center(column: Int, row: Int, rowSpan: Int = 1) -> CGPoint {
        CGPoint(
            x: inset + cell / 2 + CGFloat(column) * (cell + spacing),
            y: inset + (cell * CGFloat(rowSpan) + spacing * CGFloat(rowSpan - 1)) / 2
                + CGFloat(row) * (cell + spacing)
        )
    }
}
