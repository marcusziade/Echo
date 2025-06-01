import UIKit

final class SkeletonTableViewCell: UITableViewCell {
    static let identifier = "SkeletonTableViewCell"
    
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
    
    private let posterSkeletonView: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let showTitleSkeletonView: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let episodeInfoSkeletonView: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let episodeTitleSkeletonView: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let airDateSkeletonView: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let progressSkeletonView: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var skeletonViews: [UIView] = []
    
    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraints()
        startSkeletonAnimation()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        skeletonViews = [
            posterSkeletonView,
            showTitleSkeletonView,
            episodeInfoSkeletonView,
            episodeTitleSkeletonView,
            airDateSkeletonView,
            progressSkeletonView
        ]
        
        contentView.addSubview(containerView)
        containerView.addSubview(posterSkeletonView)
        containerView.addSubview(showTitleSkeletonView)
        containerView.addSubview(episodeInfoSkeletonView)
        containerView.addSubview(episodeTitleSkeletonView)
        containerView.addSubview(airDateSkeletonView)
        containerView.addSubview(progressSkeletonView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Poster Skeleton - Vertically centered like the real poster
            posterSkeletonView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            posterSkeletonView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            posterSkeletonView.widthAnchor.constraint(equalToConstant: 70),
            posterSkeletonView.heightAnchor.constraint(equalToConstant: 105),
            
            // Show Title Skeleton
            showTitleSkeletonView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            showTitleSkeletonView.leadingAnchor.constraint(equalTo: posterSkeletonView.trailingAnchor, constant: 12),
            showTitleSkeletonView.widthAnchor.constraint(equalToConstant: 180),
            showTitleSkeletonView.heightAnchor.constraint(equalToConstant: 20),
            
            // Episode Info Skeleton
            episodeInfoSkeletonView.topAnchor.constraint(equalTo: showTitleSkeletonView.bottomAnchor, constant: 4),
            episodeInfoSkeletonView.leadingAnchor.constraint(equalTo: showTitleSkeletonView.leadingAnchor),
            episodeInfoSkeletonView.widthAnchor.constraint(equalToConstant: 80),
            episodeInfoSkeletonView.heightAnchor.constraint(equalToConstant: 16),
            
            // Episode Title Skeleton
            episodeTitleSkeletonView.topAnchor.constraint(equalTo: episodeInfoSkeletonView.bottomAnchor, constant: 4),
            episodeTitleSkeletonView.leadingAnchor.constraint(equalTo: showTitleSkeletonView.leadingAnchor),
            episodeTitleSkeletonView.widthAnchor.constraint(equalToConstant: 150),
            episodeTitleSkeletonView.heightAnchor.constraint(equalToConstant: 16),
            
            // Air Date Skeleton
            airDateSkeletonView.topAnchor.constraint(equalTo: episodeTitleSkeletonView.bottomAnchor, constant: 8),
            airDateSkeletonView.leadingAnchor.constraint(equalTo: showTitleSkeletonView.leadingAnchor),
            airDateSkeletonView.widthAnchor.constraint(equalToConstant: 100),
            airDateSkeletonView.heightAnchor.constraint(equalToConstant: 14),
            
            // Progress Skeleton
            progressSkeletonView.topAnchor.constraint(equalTo: airDateSkeletonView.bottomAnchor, constant: 8),
            progressSkeletonView.leadingAnchor.constraint(equalTo: showTitleSkeletonView.leadingAnchor),
            progressSkeletonView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            progressSkeletonView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            progressSkeletonView.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    // MARK: - Skeleton Animation
    private func startSkeletonAnimation() {
        for view in skeletonViews {
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor.tertiarySystemBackground.cgColor,
                UIColor.quaternarySystemFill.cgColor,
                UIColor.tertiarySystemBackground.cgColor
            ]
            gradientLayer.locations = [0, 0.5, 1]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
            gradientLayer.frame = view.bounds
            
            view.layer.mask = gradientLayer
            
            let animation = CABasicAnimation(keyPath: "locations")
            animation.fromValue = [-1, -0.5, 0]
            animation.toValue = [1, 1.5, 2]
            animation.duration = 1.5
            animation.repeatCount = .infinity
            gradientLayer.add(animation, forKey: "shimmer")
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update gradient layer frames when the view layout changes
        for view in skeletonViews {
            if let gradientLayer = view.layer.mask as? CAGradientLayer {
                gradientLayer.frame = view.bounds
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Remove animations to prevent issues when reusing cells
        for view in skeletonViews {
            view.layer.mask?.removeAllAnimations()
        }
    }
}