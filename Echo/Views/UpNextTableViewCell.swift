import Foundation
import UIKit

// MARK: - Up Next Table View Cell
final class UpNextTableViewCell: UITableViewCell {
    static let identifier = "UpNextTableViewCell"

    // MARK: - UI Elements
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let posterImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .tertiarySystemBackground
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let showTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let episodeInfoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let episodeTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let airDateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.layer.cornerRadius = 2
        progress.clipsToBounds = true
        return progress
    }()

    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(posterImageView)
        containerView.addSubview(showTitleLabel)
        containerView.addSubview(episodeInfoLabel)
        containerView.addSubview(episodeTitleLabel)
        containerView.addSubview(airDateLabel)
        containerView.addSubview(progressView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Poster Image - Vertically centered in container
            posterImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            posterImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            posterImageView.widthAnchor.constraint(equalToConstant: 70),
            posterImageView.heightAnchor.constraint(equalToConstant: 105),

            // Show Title
            showTitleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            showTitleLabel.leadingAnchor.constraint(equalTo: posterImageView.trailingAnchor, constant: 12),
            showTitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            // Episode Info
            episodeInfoLabel.topAnchor.constraint(equalTo: showTitleLabel.bottomAnchor, constant: 4),
            episodeInfoLabel.leadingAnchor.constraint(equalTo: showTitleLabel.leadingAnchor),
            episodeInfoLabel.trailingAnchor.constraint(equalTo: showTitleLabel.trailingAnchor),

            // Episode Title
            episodeTitleLabel.topAnchor.constraint(equalTo: episodeInfoLabel.bottomAnchor, constant: 4),
            episodeTitleLabel.leadingAnchor.constraint(equalTo: showTitleLabel.leadingAnchor),
            episodeTitleLabel.trailingAnchor.constraint(equalTo: showTitleLabel.trailingAnchor),

            // Air Date
            airDateLabel.topAnchor.constraint(equalTo: episodeTitleLabel.bottomAnchor, constant: 8),
            airDateLabel.leadingAnchor.constraint(equalTo: showTitleLabel.leadingAnchor),
            airDateLabel.trailingAnchor.constraint(equalTo: showTitleLabel.trailingAnchor),

            // Progress View
            progressView.topAnchor.constraint(equalTo: airDateLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: showTitleLabel.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: showTitleLabel.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            progressView.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    // MARK: - Properties
    private var imageLoadingTask: Task<Void, Never>?
    
    // MARK: - Configuration
    func configure(with item: UpNextItem) {
        // Check if this is a transition from skeleton (no data) to real content
        let isTransitioningFromSkeleton = showTitleLabel.text == nil || showTitleLabel.text == ""
        
        showTitleLabel.text = item.show.title
        episodeInfoLabel.text = "S\(item.nextEpisode.season)E\(item.nextEpisode.number)"
        episodeTitleLabel.text = item.nextEpisode.title ?? "Episode \(item.nextEpisode.number)"

        // Format air date
        if let airedAt = item.nextEpisode.airedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            airDateLabel.text = formatter.localizedString(for: airedAt, relativeTo: Date())
        } else {
            airDateLabel.text = "Air date unknown"
        }

        // Set progress
        if let progress = item.progress {
            progressView.isHidden = false
            progressView.progress = Float(progress.progressPercentage / 100.0)
            progressView.tintColor = progress.isCompleted ? .systemGreen : .systemRed
        } else {
            progressView.isHidden = true
        }
        
        // Cancel previous image loading task
        imageLoadingTask?.cancel()
        
        // Load poster image with animation if transitioning from skeleton
        if let posterUrl = item.show.posterUrl {
            posterImageView.contentMode = .scaleAspectFill
            
            imageLoadingTask = Task {
                do {
                    if let image = try await ImageLoadingService.shared.loadImage(from: posterUrl) {
                        await MainActor.run {
                            if isTransitioningFromSkeleton {
                                self.animateImageIn(image)
                            } else {
                                self.posterImageView.image = image
                            }
                        }
                    } else {
                        await MainActor.run {
                            self.setPlaceholderImage()
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.setPlaceholderImage()
                    }
                }
            }
        } else {
            setPlaceholderImage()
        }
        
        // Animate text elements if transitioning from skeleton
        if isTransitioningFromSkeleton {
            animateTextElementsIn()
        }
    }
    
    private func setPlaceholderImage() {
        posterImageView.image = UIImage(systemName: "tv")
        posterImageView.tintColor = .tertiaryLabel
        posterImageView.contentMode = .scaleAspectFit
    }
    
    // MARK: - Animation Methods
    private func animateImageIn(_ image: UIImage) {
        // Start with the image invisible
        posterImageView.alpha = 0
        posterImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        posterImageView.image = image
        
        // Animate in with a beautiful fade + scale
        UIView.animate(withDuration: 0.6, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.curveEaseOut], animations: {
            self.posterImageView.alpha = 1.0
            self.posterImageView.transform = CGAffineTransform.identity
        }, completion: nil)
    }
    
    private func animateTextElementsIn() {
        let textElements = [showTitleLabel, episodeInfoLabel, episodeTitleLabel, airDateLabel, progressView]
        
        // Start with all text elements invisible with a more dramatic effect
        for (index, element) in textElements.enumerated() {
            element.alpha = 0
            element.transform = CGAffineTransform(translationX: 30, y: -10).scaledBy(x: 0.9, y: 0.9)
            
            // Stagger the animations with smoother timing
            let delay = Double(index) * 0.1 + 0.25
            
            // Use more sophisticated spring animation
            UIView.animate(withDuration: 0.8, delay: delay, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, options: [.curveEaseOut, .allowUserInteraction], animations: {
                element.alpha = 1.0
                element.transform = CGAffineTransform.identity
            }, completion: nil)
        }
        
        // Add a subtle container bounce effect
        containerView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        UIView.animate(withDuration: 0.6, delay: 0.15, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: [.curveEaseOut], animations: {
            self.containerView.transform = CGAffineTransform.identity
        }, completion: nil)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadingTask?.cancel()
        posterImageView.image = nil
        progressView.progress = 0
        
        // Reset any animations
        containerView.transform = CGAffineTransform.identity
        posterImageView.alpha = 1.0
        posterImageView.transform = CGAffineTransform.identity
        showTitleLabel.alpha = 1.0
        showTitleLabel.transform = CGAffineTransform.identity
        episodeInfoLabel.alpha = 1.0
        episodeInfoLabel.transform = CGAffineTransform.identity
        episodeTitleLabel.alpha = 1.0
        episodeTitleLabel.transform = CGAffineTransform.identity
        airDateLabel.alpha = 1.0
        airDateLabel.transform = CGAffineTransform.identity
        progressView.alpha = 1.0
        progressView.transform = CGAffineTransform.identity
    }
}
