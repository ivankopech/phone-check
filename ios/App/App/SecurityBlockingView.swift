import UIKit

// MARK: - Security Blocking View

class SecurityBlockingView: UIView {

    static let viewTag = 999

    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let reasonsLabel = UILabel()

    init(reasons: [String]) {
        super.init(frame: .zero)
        self.tag = SecurityBlockingView.viewTag
        setupUI(reasons: reasons)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    private func setupUI(reasons: [String]) {
        backgroundColor = UIColor.systemBackground
        isUserInteractionEnabled = true

        // Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        // Shield Icon
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .regular)
            let image = UIImage(systemName: "exclamationmark.shield.fill", withConfiguration: config)
            iconImageView.image = image
            iconImageView.tintColor = .systemRed
        }
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconImageView)

        // Title
        titleLabel.text = "Security Check Failed"
        titleLabel.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.text = "This app cannot run on this device for security reasons."
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(subtitleLabel)

        // Failure Reasons
        let reasonsContainer = UIView()
        reasonsContainer.backgroundColor = UIColor.secondarySystemBackground
        reasonsContainer.layer.cornerRadius = 12
        reasonsContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(reasonsContainer)

        let reasonsText = reasons.map { "• \($0)" }.joined(separator: "\n")
        reasonsLabel.text = reasonsText
        reasonsLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        reasonsLabel.textColor = .systemRed
        reasonsLabel.textAlignment = .left
        reasonsLabel.numberOfLines = 0
        reasonsLabel.translatesAutoresizingMaskIntoConstraints = false
        reasonsContainer.addSubview(reasonsLabel)

        // Layout Constraints
        NSLayoutConstraint.activate([
            // Container centered in view
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),

            // Icon
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),

            // Title
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            // Reasons Container
            reasonsContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            reasonsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            reasonsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            reasonsContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // Reasons Label inside container
            reasonsLabel.topAnchor.constraint(equalTo: reasonsContainer.topAnchor, constant: 16),
            reasonsLabel.leadingAnchor.constraint(equalTo: reasonsContainer.leadingAnchor, constant: 16),
            reasonsLabel.trailingAnchor.constraint(equalTo: reasonsContainer.trailingAnchor, constant: -16),
            reasonsLabel.bottomAnchor.constraint(equalTo: reasonsContainer.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Touch Handling (absorb all touches)

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return true
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self
    }
}
