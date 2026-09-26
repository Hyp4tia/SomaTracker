import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct SomaChatPage: View {
    @Environment(\.modelContext) private var modelContext
    @State private var session = SomaChatSession()
    @State private var subscription = SubscriptionManager.shared
    @State private var composerFocused = false
    @State private var showClearConfirmation = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            if session.messages.isEmpty {
                emptyState
            } else {
                conversation
            }

            composer
        }
        // The composer carries its own bottom inset. Ignoring the container's keeps a hidden tab
        // bar's stale safe area from floating the bar up off the screen edge. The keyboard region
        // is deliberately left alone, so the keyboard still pushes the bar up when it opens.
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Soma")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", systemImage: "trash", role: .destructive) {
                    showClearConfirmation = true
                }
                .disabled(session.messages.isEmpty || session.isThinking)
            }
        }
        .confirmationDialog("Clear this conversation?", isPresented: $showClearConfirmation) {
            Button("Clear Conversation", role: .destructive) {
                session.clear()
            }
        }
        .hideTabBarWithCoordinator()
        .sheet(isPresented: $session.needsPaywall) {
            SomaPaywallView()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapturePicker(selectedImage: $capturedImage)
                .ignoresSafeArea()
                .background(Color.black.ignoresSafeArea())
        }
        // Focus lands after viewDidAppear, which is the point at which the navigation push has
        // finished. Asking any earlier hands the keyboard the push's animation, and it rides in
        // from the side instead of rising from the bottom like a keyboard should.
        .background(ViewDidAppearReporter { composerFocused = true })
        .onAppear {
            // Belt and braces in case the reporter never appears: by 0.6s the push is over either
            // way, so the keyboard still animates upward.
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                composerFocused = true
            }
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            session.attach(image)
            capturedImage = nil
            composerFocused = true
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await attachPickerItems(items) }
        }
        .photosPicker(
            isPresented: $showLibrary,
            selection: $pickerItems,
            maxSelectionCount: max(0, 5 - session.pendingPhotos.count),
            matching: .images
        )
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(session.messages) { message in
                        SomaChatBubble(message: message)
                            .id(message.id)
                    }

                    if session.isThinking {
                        SomaThinkingStatus()
                            .id("thinking")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                // Pin the content column to the viewport width, same as the paywall does: an
                // over-wide child (a line that will not wrap) otherwise drags the whole page wider
                // than the screen instead of wrapping inside it.
                .containerRelativeFrame(.horizontal)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.never)
            .clipped()
            .onChange(of: session.messages.count) { _, _ in
                if let id = session.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            .onChange(of: session.isThinking) { _, thinking in
                if thinking {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("thinking", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        GeometryReader { geo in
            ScrollView {
                // Top-anchored, not centred: the page's first frame is always keyboard-less, so
                // centring would lift the whole welcome by a quarter of the screen the moment the
                // keyboard arrives. Pinned to the top, only the bottom edge moves.
                welcome
                    .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    /// Short by design, so it clears the open keyboard on any phone. The scroll view stays for the
    /// case where a large text size would still overflow.
    private var welcome: some View {
        VStack(spacing: 10) {
            heroMark

            VStack(spacing: 4) {
                Text("Hi, I'm Soma")
                    .font(.title2.bold())

                Text("Ask me about meals, goals, and recipes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            brandLockup
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    /// The app's own mascot on the squircle treatment the splash gives it. Generic drawn symbols
    /// here read as decoration; the mascot is the one mark that is already Soma.
    private var heroMark: some View {
        Image("soma-icon")
            .resizable()
            .scaledToFit()
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(SomaColors.navy.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: SomaColors.navy.opacity(0.12), radius: 9, y: 4)
            .accessibilityHidden(true)
    }

    private var brandLockup: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                SomaLockupCurve()
                    .stroke(Color(.separator), style: StrokeStyle(lineWidth: 1, lineCap: .round))

                Image(systemName: "leaf.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(SomaColors.emerald)

                SomaLockupCurve()
                    .stroke(Color(.separator), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .scaleEffect(x: -1, y: 1)
            }
            .frame(height: 8)

            Text("Better food • better you")
                .font(.system(size: 11, weight: .medium))
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(SomaColors.subtext)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 7) {
            if !session.pendingPhotos.isEmpty {
                pendingPhotoStrip
            }

            if !subscription.isPro {
                Text("\(subscription.remainingFreeScans) free AI requests left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                attachControl

                SomaComposerField(
                    text: $session.input,
                    placeholder: "Ask or log food...",
                    wantsFocus: composerFocused,
                    onSend: send,
                    onFocusChange: { composerFocused = $0 }
                )
                .frame(minHeight: 44)

                sendControl
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .background(Capsule(style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.45), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 16)
        }
        .padding(.top, 6)
        // The keyboard brings its own inset; the device's is only ours to add while the field is
        // idle, which is what keeps the bar docked to the bottom edge.
        .padding(.bottom, composerFocused ? 6 : deviceBottomInset)
    }

    private var attachControl: some View {
        // One attach control instead of separate photo and camera buttons: three 44pt targets
        // crowded the field until the placeholder truncated.
        Menu {
            Button("Take Photo", systemImage: "camera") {
                composerFocused = false
                showCamera = true
            }
            Button("Choose Photos", systemImage: "photo.on.rectangle") {
                showLibrary = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SomaColors.navy)
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .disabled(session.pendingPhotos.count >= 5)
        .accessibilityLabel("Add meal photos")
    }

    private var sendControl: some View {
        Button(action: send) {
            Image(systemName: "arrow.up")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(canSend ? SomaColors.navy : Color(.tertiaryLabel))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .accessibilityLabel("Send")
    }

    private var pendingPhotoStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(session.pendingPhotos.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button {
                                session.removePendingPhoto(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove photo")
                            .offset(x: 5, y: -5)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Helpers

    private var canSend: Bool {
        (!session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !session.pendingPhotos.isEmpty)
            && !session.isThinking
    }

    /// The device's own bottom inset (the home indicator), read from the window so a hidden tab
    /// bar's safe area cannot inflate it, and floored at 16pt so the pill keeps air on phones
    /// without a home indicator.
    private var deviceBottomInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        return max(window?.safeAreaInsets.bottom ?? 0, 16)
    }

    private func send() {
        guard canSend else { return }
        Task { await session.send(context: modelContext, subscription: subscription) }
    }

    private func attachPickerItems(_ items: [PhotosPickerItem]) async {
        pickerItems = []
        for item in items {
            guard session.pendingPhotos.count < 5,
                  let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            session.attach(image)
        }
        composerFocused = true
    }
}

/// Fires once, the first time its view controller appears on screen. `onAppear` is too early
/// for anything that must not be caught up in a navigation transition, and `viewDidAppear` is
/// UIKit's own signal that the transition has finished.
private struct ViewDidAppearReporter: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> Reporter {
        let reporter = Reporter()
        reporter.action = action
        return reporter
    }

    func updateUIViewController(_ controller: Reporter, context: Context) {}

    final class Reporter: UIViewController {
        var action: (() -> Void)?
        private var hasReported = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !hasReported else { return }
            hasReported = true
            action?()
        }
    }
}

/// Shallow arc on either side of the brand lockup's sprout: level with the sprout, bowing up
/// toward the outside. The trailing copy is mirrored with scaleEffect.
private struct SomaLockupCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY + 1.5))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.midY - 1.5),
            control1: CGPoint(x: rect.maxX - rect.width * 0.33, y: rect.midY - 4),
            control2: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.midY - 4)
        )
        return path
    }
}
