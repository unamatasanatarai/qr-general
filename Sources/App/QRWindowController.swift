import Cocoa
import UniformTypeIdentifiers

public final class QRWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, NSTextFieldDelegate, NSMenuItemValidation {
    public static let defaultSize = 1000
    private static let previewMaxSize = 1200
    private static let logoRasterSize: CGFloat = 2048

    // MARK: - Public Properties (Preserved for tests)
    private let textScrollView = NSTextView.scrollableTextView()
    private let placeholderLabel = NSTextField(labelWithString: "Type or paste text / URL to generate QR…")
    private let charCountLabel = NSTextField(labelWithString: "")

    public let sizeField = NSTextField(string: String(QRWindowController.defaultSize))
    private let sizePresets = NSSegmentedControl()
       // Error correction controls (Pills + legacy popup synced for test compatibility)
    private let errorPills = NSSegmentedControl()
    public let correctionPopUp = NSPopUpButton()
    private let errorHelpLabel = NSTextField(labelWithString: "Maximum 30% recovery · Recommended for logos")

    // MARK: - Logo Controls
    private let placeholderImage: NSImage? = {
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .light)
            return NSImage(systemSymbolName: "photo.badge.plus", accessibilityDescription: "Add Logo")?.withSymbolConfiguration(config)
        }
        return nil
    }()

    public let logoWell = NSImageView()
    private let logoSlider = NSSlider()
    private let logoScaleLabel = NSTextField(labelWithString: "30%")
    private let removeLogoButton = NSButton(title: "Remove", target: nil, action: nil)
    public let chooseLogoButton = NSButton(title: "Choose Image…", target: nil, action: nil)
    private let changeLogoButton = NSButton(title: "Change…", target: nil, action: nil)
    private let logoHintLabel = NSTextField(labelWithString: "Optional · Sets 30% recovery")
    private let logoEmptyStack = NSStackView()
    private let logoActiveStack = NSStackView()
    private let logoScaleStack = NSStackView()

    public let previewView = PreviewImageView()
    private let previewContainer = NSView()
    private let emptyPlaceholderView = NSStackView()
    private let emptyStarView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = QRWindowController.loadGeneralStar()
        iv.alphaValue = 0.75
        return iv
    }()
    private let emptyLabel = NSTextField(labelWithString: "")

    public let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save PNG…", target: nil, action: nil)
    private var copyResetWorkItem: DispatchWorkItem?

    private var logoImage: CGImage?
    private var currentMatrix: QRMatrix?

    public var textView: NSTextView {
        return textScrollView.documentView as! NSTextView
    }

    public var hasQRCode: Bool {
        return currentMatrix != nil
    }

    // MARK: - Initialization

    public init() {
        let fixedSize = NSSize(width: 620, height: 400)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: fixedSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppConfig.appName
        window.contentMinSize = fixedSize
        window.contentMaxSize = fixedSize
        window.minSize = fixedSize
        window.maxSize = fixedSize
        window.setFrameAutosaveName("QRGeneral_NativeTitle_v6")

        super.init(window: window)
        window.delegate = self
        buildUI()
        window.center()
        window.initialFirstResponder = textView
        regenerate()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - UI Construction

    private func buildUI() {
        guard let window = window, let contentView = window.contentView else { return }

        // Vibrancy background
        let visualEffect = NSVisualEffectView(frame: contentView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .sidebar
        visualEffect.state = .active
        contentView.addSubview(visualEffect)

        // Left & Right Panels (50% / 50% split)
        let leftPanel = buildLeftPanel()
        let rightPanel = buildRightPanel()

        let splitStack = NSStackView(views: [leftPanel, rightPanel])
        splitStack.orientation = .horizontal
        splitStack.alignment = .top
        splitStack.distribution = .fill
        splitStack.spacing = 14
        splitStack.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(splitStack)

        NSLayoutConstraint.activate([
            splitStack.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 14),
            splitStack.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -14),
            splitStack.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 14),
            splitStack.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -14),

            // Left and Right panels each take exactly 50% of the content width
            leftPanel.widthAnchor.constraint(equalTo: rightPanel.widthAnchor)
        ])

        updateLogoControls()
    }

    private func buildLeftPanel() -> NSView {
        let leftColumn = NSStackView()
        leftColumn.orientation = .vertical
        leftColumn.alignment = .leading
        leftColumn.spacing = 8
        leftColumn.translatesAutoresizingMaskIntoConstraints = false

        // 1. Text Input Card: Expands when window resizes
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.delegate = self
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 4)

        textScrollView.borderType = .noBorder
        textScrollView.drawsBackground = false
        textScrollView.hasVerticalScroller = true
        textScrollView.autohidesScrollers = true

        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        charCountLabel.textColor = .tertiaryLabelColor
        charCountLabel.font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular)

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearText(_:)))
        clearButton.bezelStyle = .inline
        clearButton.font = NSFont.systemFont(ofSize: 9.5, weight: .medium)

        let inputBottomRow = NSStackView(views: [charCountLabel, NSView(), clearButton])
        inputBottomRow.orientation = .horizontal
        inputBottomRow.alignment = .centerY
        inputBottomRow.spacing = 4

        let textCard = CompactCardView()
        textCard.translatesAutoresizingMaskIntoConstraints = false
        textCard.addSubview(textScrollView)
        textCard.addSubview(placeholderLabel)
        textCard.addSubview(inputBottomRow)
        textScrollView.translatesAutoresizingMaskIntoConstraints = false
        inputBottomRow.translatesAutoresizingMaskIntoConstraints = false

        textCard.setContentHuggingPriority(.defaultLow, for: .vertical)
        textScrollView.setContentHuggingPriority(.defaultLow, for: .vertical)

        NSLayoutConstraint.activate([
            textScrollView.leadingAnchor.constraint(equalTo: textCard.leadingAnchor, constant: 6),
            textScrollView.trailingAnchor.constraint(equalTo: textCard.trailingAnchor, constant: -6),
            textScrollView.topAnchor.constraint(equalTo: textCard.topAnchor, constant: 4),
            textScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            placeholderLabel.leadingAnchor.constraint(equalTo: textCard.leadingAnchor, constant: 10),
            placeholderLabel.topAnchor.constraint(equalTo: textCard.topAnchor, constant: 8),

            inputBottomRow.leadingAnchor.constraint(equalTo: textCard.leadingAnchor, constant: 8),
            inputBottomRow.trailingAnchor.constraint(equalTo: textCard.trailingAnchor, constant: -8),
            inputBottomRow.topAnchor.constraint(equalTo: textScrollView.bottomAnchor, constant: 2),
            inputBottomRow.bottomAnchor.constraint(equalTo: textCard.bottomAnchor, constant: -4)
        ])

        // 2. Settings Card: Size & Error Correction (Hugs tightly)
        sizePresets.segmentCount = 4
        sizePresets.setLabel("512", forSegment: 0)
        sizePresets.setLabel("1K", forSegment: 1)
        sizePresets.setLabel("2K", forSegment: 2)
        sizePresets.setLabel("4K", forSegment: 3)
        sizePresets.selectedSegment = 1
        sizePresets.target = self
        sizePresets.action = #selector(sizePresetSelected(_:))
        sizePresets.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        sizePresets.controlSize = .small

        sizeField.delegate = self
        sizeField.alignment = .right
        sizeField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        sizeField.widthAnchor.constraint(equalToConstant: 48).isActive = true
        sizeField.bezelStyle = .roundedBezel
        sizeField.controlSize = .small

        let sizeRow = NSStackView(views: [sizePresets, sizeField, miniLabel("px")])
        sizeRow.orientation = .horizontal
        sizeRow.alignment = .centerY
        sizeRow.spacing = 6

        errorPills.segmentCount = 4
        errorPills.setLabel("7%", forSegment: 0)
        errorPills.setLabel("15%", forSegment: 1)
        errorPills.setLabel("25%", forSegment: 2)
        errorPills.setLabel("30%", forSegment: 3)
        errorPills.selectedSegment = 3 // High (30%)
        errorPills.target = self
        errorPills.action = #selector(errorPillSelected(_:))
        errorPills.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        errorPills.controlSize = .small

        // Legacy PopUp preserved invisible/synced for tests
        correctionPopUp.removeAllItems()
        for level in QRErrorCorrection.allCases {
            correctionPopUp.addItem(withTitle: level.title)
            correctionPopUp.lastItem?.representedObject = level.rawValue
        }
        correctionPopUp.selectItem(at: QRErrorCorrection.allCases.firstIndex(of: .high) ?? 3)
        correctionPopUp.target = self
        correctionPopUp.action = #selector(optionsChanged(_:))
        correctionPopUp.isHidden = true

        errorHelpLabel.font = NSFont.systemFont(ofSize: 9.0, weight: .regular)
        errorHelpLabel.textColor = .secondaryLabelColor

        let errorCol = NSStackView(views: [errorPills, errorHelpLabel, correctionPopUp])
        errorCol.orientation = .vertical
        errorCol.alignment = .leading
        errorCol.spacing = 2

        let settingsGrid = NSGridView(views: [
            [miniLabel("Size:"), sizeRow],
            [miniLabel("Error:"), errorCol]
        ])
        settingsGrid.column(at: 0).xPlacement = .trailing
        settingsGrid.rowAlignment = .firstBaseline
        settingsGrid.columnSpacing = 8
        settingsGrid.rowSpacing = 6

        let settingsCard = CompactCardView()
        settingsCard.translatesAutoresizingMaskIntoConstraints = false
        settingsCard.addSubview(settingsGrid)
        settingsGrid.translatesAutoresizingMaskIntoConstraints = false

        settingsCard.setContentHuggingPriority(.required, for: .vertical)
        settingsCard.setContentCompressionResistancePriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            settingsGrid.leadingAnchor.constraint(equalTo: settingsCard.leadingAnchor, constant: 8),
            settingsGrid.trailingAnchor.constraint(equalTo: settingsCard.trailingAnchor, constant: -8),
            settingsGrid.topAnchor.constraint(equalTo: settingsCard.topAnchor, constant: 6),
            settingsGrid.bottomAnchor.constraint(equalTo: settingsCard.bottomAnchor, constant: -6)
        ])

        // 3. Dedicated Logo / Emblem Card: Prominent, spacious, natural
        let logoCard = CompactCardView()
        logoCard.translatesAutoresizingMaskIntoConstraints = false
        logoCard.setContentHuggingPriority(.required, for: .vertical)
        logoCard.setContentCompressionResistancePriority(.required, for: .vertical)

        logoWell.isEditable = true
        logoWell.imageFrameStyle = .none
        logoWell.imageScaling = .scaleProportionallyUpOrDown
        logoWell.toolTip = "Click to choose logo, or drag an image here"
        logoWell.target = self
        logoWell.action = #selector(logoWellChanged(_:))
        logoWell.wantsLayer = true
        logoWell.layer?.cornerRadius = 8
        logoWell.layer?.masksToBounds = true
        logoWell.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        logoWell.layer?.borderWidth = 1.0
        logoWell.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
        logoWell.translatesAutoresizingMaskIntoConstraints = false
        logoWell.widthAnchor.constraint(equalToConstant: 52).isActive = true
        logoWell.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let wellClick = NSClickGestureRecognizer(target: self, action: #selector(chooseLogo(_:)))
        logoWell.addGestureRecognizer(wellClick)

        // Empty state view
        let logoTitleLabel = NSTextField(labelWithString: "Center Emblem")
        logoTitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        logoTitleLabel.textColor = .labelColor

        logoHintLabel.font = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        logoHintLabel.textColor = .secondaryLabelColor

        chooseLogoButton.target = self
        chooseLogoButton.action = #selector(chooseLogo(_:))
        chooseLogoButton.bezelStyle = .rounded
        chooseLogoButton.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        chooseLogoButton.controlSize = .small
        chooseLogoButton.title = "Choose Image…"

        let emptyHeaderStack = NSStackView(views: [logoTitleLabel, logoHintLabel])
        emptyHeaderStack.orientation = .vertical
        emptyHeaderStack.alignment = .leading
        emptyHeaderStack.spacing = 1

        logoEmptyStack.orientation = .vertical
        logoEmptyStack.alignment = .leading
        logoEmptyStack.spacing = 4
        logoEmptyStack.addArrangedSubview(emptyHeaderStack)
        logoEmptyStack.addArrangedSubview(chooseLogoButton)

        // Active state view (When logo is set)
        changeLogoButton.target = self
        changeLogoButton.action = #selector(chooseLogo(_:))
        changeLogoButton.bezelStyle = .rounded
        changeLogoButton.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        changeLogoButton.controlSize = .small
        changeLogoButton.title = "Change…"

        removeLogoButton.target = self
        removeLogoButton.action = #selector(removeLogo(_:))
        removeLogoButton.bezelStyle = .rounded
        removeLogoButton.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        removeLogoButton.controlSize = .small
        removeLogoButton.title = "Remove"

        let logoButtonsRow = NSStackView(views: [changeLogoButton, removeLogoButton])
        logoButtonsRow.orientation = .horizontal
        logoButtonsRow.alignment = .centerY
        logoButtonsRow.spacing = 6

        logoSlider.minValue = Double(QRRenderer.logoScaleRange.lowerBound * 100)
        logoSlider.maxValue = Double(QRRenderer.logoScaleRange.upperBound * 100)
        logoSlider.doubleValue = 30
        logoSlider.isContinuous = true
        logoSlider.target = self
        logoSlider.action = #selector(optionsChanged(_:))
        logoSlider.controlSize = .small

        logoScaleLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
        logoScaleLabel.textColor = .secondaryLabelColor

        logoScaleStack.orientation = .horizontal
        logoScaleStack.alignment = .centerY
        logoScaleStack.spacing = 4
        logoScaleStack.addArrangedSubview(miniLabel("Scale:"))
        logoScaleStack.addArrangedSubview(logoSlider)
        logoScaleStack.addArrangedSubview(logoScaleLabel)

        logoActiveStack.orientation = .vertical
        logoActiveStack.alignment = .leading
        logoActiveStack.spacing = 4
        logoActiveStack.addArrangedSubview(logoButtonsRow)
        logoActiveStack.addArrangedSubview(logoScaleStack)

        let logoDetailsContainer = NSView()
        logoDetailsContainer.translatesAutoresizingMaskIntoConstraints = false
        logoEmptyStack.translatesAutoresizingMaskIntoConstraints = false
        logoActiveStack.translatesAutoresizingMaskIntoConstraints = false
        logoDetailsContainer.addSubview(logoEmptyStack)
        logoDetailsContainer.addSubview(logoActiveStack)

        NSLayoutConstraint.activate([
            logoEmptyStack.leadingAnchor.constraint(equalTo: logoDetailsContainer.leadingAnchor),
            logoEmptyStack.trailingAnchor.constraint(lessThanOrEqualTo: logoDetailsContainer.trailingAnchor),
            logoEmptyStack.centerYAnchor.constraint(equalTo: logoDetailsContainer.centerYAnchor),

            logoActiveStack.leadingAnchor.constraint(equalTo: logoDetailsContainer.leadingAnchor),
            logoActiveStack.trailingAnchor.constraint(equalTo: logoDetailsContainer.trailingAnchor),
            logoActiveStack.centerYAnchor.constraint(equalTo: logoDetailsContainer.centerYAnchor)
        ])

        let logoCardRow = NSStackView(views: [logoWell, logoDetailsContainer])
        logoCardRow.orientation = .horizontal
        logoCardRow.alignment = .centerY
        logoCardRow.spacing = 10
        logoCardRow.translatesAutoresizingMaskIntoConstraints = false

        logoCard.addSubview(logoCardRow)

        NSLayoutConstraint.activate([
            logoCardRow.leadingAnchor.constraint(equalTo: logoCard.leadingAnchor, constant: 8),
            logoCardRow.trailingAnchor.constraint(equalTo: logoCard.trailingAnchor, constant: -8),
            logoCardRow.topAnchor.constraint(equalTo: logoCard.topAnchor, constant: 6),
            logoCardRow.bottomAnchor.constraint(equalTo: logoCard.bottomAnchor, constant: -6)
        ])

        leftColumn.addArrangedSubview(textCard)
        leftColumn.addArrangedSubview(settingsCard)
        leftColumn.addArrangedSubview(logoCard)

        textCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor).isActive = true
        settingsCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor).isActive = true
        logoCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor).isActive = true

        return leftColumn
    }

    private func buildRightPanel() -> NSView {
        let rightColumn = NSStackView()
        rightColumn.orientation = .vertical
        rightColumn.alignment = .centerX
        rightColumn.spacing = 10
        rightColumn.translatesAutoresizingMaskIntoConstraints = false

        // Elevated QR Canvas
        previewContainer.wantsLayer = true
        previewContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        previewContainer.layer?.cornerRadius = 8
        previewContainer.layer?.shadowColor = NSColor.black.cgColor
        previewContainer.layer?.shadowOpacity = 0.08
        previewContainer.layer?.shadowRadius = 5
        previewContainer.layer?.shadowOffset = CGSize(width: 0, height: -1.5)
        previewContainer.translatesAutoresizingMaskIntoConstraints = false

        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.imageFrameStyle = .none
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewView)

        // Empty state placeholder
        emptyStarView.widthAnchor.constraint(equalToConstant: 72).isActive = true
        emptyStarView.heightAnchor.constraint(equalToConstant: 72).isActive = true

        emptyLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center

        emptyPlaceholderView.orientation = .vertical
        emptyPlaceholderView.alignment = .centerX
        emptyPlaceholderView.spacing = 6
        emptyPlaceholderView.addArrangedSubview(emptyStarView)
        emptyPlaceholderView.addArrangedSubview(emptyLabel)
        emptyPlaceholderView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(emptyPlaceholderView)

        copyButton.target = self
        copyButton.action = #selector(copyQRCode(_:))
        copyButton.bezelStyle = .rounded
        copyButton.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        copyButton.controlSize = .regular

        saveButton.target = self
        saveButton.action = #selector(saveQRCode(_:))
        saveButton.bezelStyle = .rounded
        saveButton.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        saveButton.controlSize = .regular
        saveButton.keyEquivalent = "\r"

        let actionsRow = NSStackView(views: [copyButton, saveButton])
        actionsRow.orientation = .horizontal
        actionsRow.alignment = .centerY
        actionsRow.spacing = 10

        rightColumn.addArrangedSubview(previewContainer)
        // Note: statusLabel is intentionally not arranged in rightColumn to eliminate the clutter below the QR
        rightColumn.addArrangedSubview(actionsRow)

        let heightConstraint = previewContainer.heightAnchor.constraint(equalTo: previewContainer.widthAnchor)
        heightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            previewContainer.widthAnchor.constraint(equalTo: rightColumn.widthAnchor),
            heightConstraint,

            previewView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 6),
            previewView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -6),
            previewView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 6),
            previewView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -6),

            emptyPlaceholderView.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            emptyPlaceholderView.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor)
        ])

        return rightColumn
    }

    private func miniLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        l.textColor = .secondaryLabelColor
        return l
    }

    // MARK: - Options & Logic

    private var correction: QRErrorCorrection {
        let raw = correctionPopUp.selectedItem?.representedObject as? String
        return raw.flatMap(QRErrorCorrection.init(rawValue:)) ?? .high
    }

    private var logoScale: CGFloat {
        return CGFloat(logoSlider.doubleValue / 100)
    }

    public var requestedSize: Int? {
        let digits = sizeField.stringValue.trimmingCharacters(in: .whitespaces)
        guard let size = Int(digits), (1...QRRenderer.maximumSize).contains(size) else { return nil }
        return size
    }

    private func renderOptions(size: Int) -> QRRenderOptions {
        return QRRenderOptions(size: size, logo: logoImage, logoScale: logoScale)
    }

    // MARK: - Rendering & Regeneration

    public func regenerate() {
        let text = textView.string
        placeholderLabel.isHidden = !text.isEmpty
        charCountLabel.stringValue = text.isEmpty ? "" : "\(text.count) chars"
        logoScaleLabel.stringValue = "\(Int(logoSlider.doubleValue.rounded()))%"

        currentMatrix = nil

        do {
            guard let size = requestedSize else { throw QRError.invalidSize }
            let matrix = try QRRenderer.matrix(for: text, correction: correction)
            let minAllowed = matrix.count + 8
            guard size >= minAllowed else { throw QRError.sizeTooSmall(minimum: minAllowed) }

            let previewSize = min(size, Self.previewMaxSize)
            let preview = try QRRenderer.render(matrix, options: renderOptions(size: previewSize))
            currentMatrix = matrix
            previewView.image = NSImage(cgImage: preview, size: .zero)
            previewContainer.layer?.backgroundColor = NSColor.white.cgColor
            emptyPlaceholderView.isHidden = true
            emptyLabel.isHidden = true
            emptyLabel.stringValue = ""
            statusLabel.stringValue = ""
        } catch {
            previewView.image = nil
            previewContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
            emptyPlaceholderView.isHidden = false
            if text.isEmpty {
                emptyLabel.isHidden = true
                emptyLabel.stringValue = ""
            } else {
                emptyLabel.isHidden = false
                if let qrErr = error as? QRError {
                    switch qrErr {
                    case .textTooLong: emptyLabel.stringValue = "Text Exceeds Capacity"
                    case .invalidSize: emptyLabel.stringValue = "Invalid Size"
                    case .sizeTooSmall: emptyLabel.stringValue = "Size Too Small"
                    default: emptyLabel.stringValue = "Render Failed"
                    }
                } else {
                    emptyLabel.stringValue = "Render Failed"
                }
            }
            statusLabel.stringValue = ""
        }

        copyButton.isEnabled = hasQRCode
        saveButton.isEnabled = hasQRCode
    }

    public func renderFullSize() throws -> CGImage {
        guard let matrix = currentMatrix else { throw QRError.emptyText }
        guard let size = requestedSize else { throw QRError.invalidSize }
        return try QRRenderer.render(matrix, options: renderOptions(size: size))
    }

    public static func pngData(for image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - Actions

    public func textDidChange(_ notification: Notification) {
        regenerate()
    }

    public func controlTextDidChange(_ notification: Notification) {
        if let current = requestedSize {
            switch current {
            case 512: sizePresets.selectedSegment = 0
            case 1000: sizePresets.selectedSegment = 1
            case 2048: sizePresets.selectedSegment = 2
            case 4096: sizePresets.selectedSegment = 3
            default: sizePresets.selectedSegment = -1
            }
        } else {
            sizePresets.selectedSegment = -1
        }
        regenerate()
    }

    @objc private func sizePresetSelected(_ sender: NSSegmentedControl) {
        let values = [512, 1000, 2048, 4096]
        if sender.selectedSegment >= 0 && sender.selectedSegment < values.count {
            sizeField.stringValue = String(values[sender.selectedSegment])
            regenerate()
        }
    }

    @objc private func errorPillSelected(_ sender: NSSegmentedControl) {
        let levels: [QRErrorCorrection] = [.low, .medium, .quartile, .high]
        guard sender.selectedSegment >= 0 && sender.selectedSegment < levels.count else { return }
        let selectedLevel = levels[sender.selectedSegment]
        correctionPopUp.selectItem(at: sender.selectedSegment)
        updateErrorHelpLabel(for: selectedLevel)
        regenerate()
    }

    private func updateErrorHelpLabel(for level: QRErrorCorrection) {
        switch level {
        case .low:
            errorHelpLabel.stringValue = "7% recovery · Smallest QR code"
        case .medium:
            errorHelpLabel.stringValue = "15% recovery · Standard general use"
        case .quartile:
            errorHelpLabel.stringValue = "25% recovery · High scratch resistance"
        case .high:
            errorHelpLabel.stringValue = "30% recovery · Recommended for logos"
        }
    }

    @objc private func optionsChanged(_ sender: Any?) {
        if let idx = QRErrorCorrection.allCases.firstIndex(of: correction) {
            errorPills.selectedSegment = idx
            updateErrorHelpLabel(for: correction)
        }
        logoScaleLabel.stringValue = "\(Int(logoSlider.doubleValue.rounded()))%"

        // Fast path: if only logo slider moved and we already have a valid matrix, re-render preview directly
        if let slider = sender as? NSSlider, slider === logoSlider, let matrix = currentMatrix, let size = requestedSize {
            if let preview = try? QRRenderer.render(matrix, options: renderOptions(size: min(size, Self.previewMaxSize))) {
                previewView.image = NSImage(cgImage: preview, size: .zero)
                emptyPlaceholderView.isHidden = true
                return
            }
        }

        regenerate()
    }

    @objc private func clearText(_ sender: Any?) {
        guard let textStorage = textView.textStorage, textStorage.length > 0 else { return }
        if textView.shouldChangeText(in: NSRange(location: 0, length: textStorage.length), replacementString: "") {
            textView.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: "")
            textView.didChangeText()
        }
    }

    @objc public func chooseLogo(_ sender: Any?) {
        guard let window = window, window.attachedSheet == nil else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose an emblem or logo for the QR code"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            guard let image = NSImage(contentsOf: url) else {
                DispatchQueue.main.async {
                    self?.showError(message: "Could not open \(url.lastPathComponent) as an image.")
                }
                return
            }
            self?.setLogo(image)
        }
    }

    @objc public func removeLogo(_ sender: Any?) {
        setLogo(nil)
    }

    @objc private func logoWellChanged(_ sender: Any?) {
        if logoWell.image === placeholderImage {
            setLogo(nil)
        } else {
            setLogo(logoWell.image)
        }
    }

    public func setLogo(_ image: NSImage?) {
        if let image = image, image !== placeholderImage {
            logoWell.image = image
            logoWell.contentTintColor = nil
            logoImage = Self.rasterizedLogo(from: image)
            if logoImage != nil {
                // Adding a logo auto-selects High (30%)
                errorPills.selectedSegment = 3
                correctionPopUp.selectItem(at: 3)
                updateErrorHelpLabel(for: .high)
            }
        } else {
            logoImage = nil
            logoWell.image = placeholderImage
            logoWell.contentTintColor = .tertiaryLabelColor
        }
        updateLogoControls()
        regenerate()
    }

    private func updateLogoControls() {
        let hasLogo = logoImage != nil
        logoEmptyStack.isHidden = hasLogo
        logoActiveStack.isHidden = !hasLogo

        if hasLogo {
            logoWell.contentTintColor = nil
            logoWell.layer?.borderColor = NSColor.systemGoldColor.withAlphaComponent(0.85).cgColor
            logoWell.layer?.borderWidth = 1.5
        } else {
            logoWell.image = placeholderImage
            logoWell.contentTintColor = .tertiaryLabelColor
            logoWell.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
            logoWell.layer?.borderWidth = 1.0
        }
    }

    private static func loadGeneralStar() -> NSImage? {
        if let image = NSImage(named: NSImage.Name("GeneralStar")) {
            return image
        }
        if let url = Bundle.main.url(forResource: "GeneralStar", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.main.url(forResource: "GeneralStar", withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        for path in ["Resources/GeneralStar.png", "Resources/GeneralStar.svg"] {
            if let image = NSImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }

    private static func rasterizedLogo(from image: NSImage) -> CGImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        var rect = NSRect(origin: .zero, size: size)
        if let direct = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return direct
        }
        let width = Int(min(size.width, logoRasterSize))
        let height = Int(min(size.height, logoRasterSize))
        guard width > 0, height > 0 else { return nil }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    @objc public func copyQRCode(_ sender: Any?) {
        do {
            let image = try renderFullSize()
            guard let png = Self.pngData(for: image) else { throw QRError.renderFailed }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(png, forType: .png)
            pasteboard.setData(NSBitmapImageRep(cgImage: image).tiffRepresentation, forType: .tiff)
            copyButton.title = "✓ Copied!"
            copyResetWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.copyButton.title = "Copy"
            }
            copyResetWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    @objc public func saveQRCode(_ sender: Any?) {
        guard let window = window, hasQRCode, window.attachedSheet == nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "QR Code.png"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            do {
                guard let png = Self.pngData(for: try self.renderFullSize()) else { throw QRError.renderFailed }
                try png.write(to: url, options: .atomic)
            } catch {
                DispatchQueue.main.async {
                    self.showError(message: error.localizedDescription)
                }
            }
        }
    }

    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(saveQRCode(_:)), #selector(copyQRCode(_:)):
            return hasQRCode
        case #selector(removeLogo(_:)):
            return logoImage != nil
        default:
            return true
        }
    }

    private func showError(message: String) {
        guard let window = window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.beginSheetModal(for: window)
    }
}

// MARK: - Supporting Views

public final class CompactCardView: NSView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override var wantsUpdateLayer: Bool {
        return true
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
    }

    public override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.40).cgColor
        layer?.borderWidth = 1.0
    }
}

public final class PreviewImageView: NSImageView {
    public override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

private extension NSColor {
    static var systemGoldColor: NSColor {
        return NSColor(calibratedRed: 0.90, green: 0.72, blue: 0.15, alpha: 1.0)
    }
}
