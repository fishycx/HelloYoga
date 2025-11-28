import UIKit

public enum RefreshState {
    case idle
    case pulling
    case willRefresh
    case refreshing
    case completed
}

public protocol RefreshViewProtocol: UIView {
    func refreshStateChanged(to state: RefreshState)
    func updateProgress(_ progress: CGFloat)
}

public class RefreshControl: NSObject {
    private weak var scrollView: UIScrollView?
    private let refreshView: RefreshViewProtocol
    private let threshold: CGFloat
    
    public var onRefresh: (() -> Void)?
    
    private var state: RefreshState = .idle {
        didSet {
            refreshView.refreshStateChanged(to: state)
        }
    }
    
    private var isObserving = false
    
    public init(scrollView: UIScrollView, refreshView: RefreshViewProtocol, threshold: CGFloat = 60.0) {
        self.scrollView = scrollView
        self.refreshView = refreshView
        self.threshold = threshold
        super.init()
        
        setupView()
        startObserving()
    }
    
    deinit {
        stopObserving()
    }
    
    private func setupView() {
        scrollView?.addSubview(refreshView)
        updateFrame()
    }
    
    public func updateFrame() {
        guard let scrollView = scrollView else { return }
        refreshView.frame = CGRect(x: 0, y: -threshold, width: scrollView.bounds.width, height: threshold)
    }
    
    private func startObserving() {
        guard !isObserving, let scrollView = scrollView else { return }
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePanStateChange))
        isObserving = true
    }
    
    private func stopObserving() {
        guard isObserving, let scrollView = scrollView else { return }
        scrollView.removeObserver(self, forKeyPath: "contentOffset")
        scrollView.panGestureRecognizer.removeTarget(self, action: #selector(handlePanStateChange))
        isObserving = false
    }
    
    @objc private func handlePanStateChange() {
        guard let scrollView = scrollView else { return }
        if scrollView.panGestureRecognizer.state == .ended {
            if state == .willRefresh {
                beginRefreshing()
            }
        }
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "contentOffset", let scrollView = scrollView else { return }
        
        if state == .refreshing { return }
        
        let offsetY = scrollView.contentOffset.y
        if offsetY >= 0 {
            state = .idle
            return
        }
        
        let progress = min(abs(offsetY) / threshold, 1.0)
        refreshView.updateProgress(progress)
        
        if scrollView.isDragging {
            if abs(offsetY) >= threshold {
                state = .willRefresh
            } else {
                state = .pulling
            }
        }
    }
    
    public func beginRefreshing() {
        guard state != .refreshing, let scrollView = scrollView else { return }
        
        state = .refreshing
        
        var inset = scrollView.contentInset
        inset.top += threshold
        
        UIView.animate(withDuration: 0.3) {
            scrollView.contentInset = inset
        }
        
        onRefresh?()
    }
    
    public func endRefreshing() {
        guard state == .refreshing, let scrollView = scrollView else { return }
        
        state = .completed
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            var inset = scrollView.contentInset
            inset.top -= self.threshold
            
            UIView.animate(withDuration: 0.3, animations: {
                scrollView.contentInset = inset
            }) { _ in
                self.state = .idle
            }
        }
    }
}

