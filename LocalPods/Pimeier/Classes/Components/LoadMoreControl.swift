import UIKit

public enum LoadMoreState {
    case idle
    case loading
    case noMore
    case error
}

public protocol LoadMoreViewProtocol: UIView {
    func loadMoreStateChanged(to state: LoadMoreState)
}

public class LoadMoreControl: NSObject {
    private weak var scrollView: UIScrollView?
    private let loadMoreView: LoadMoreViewProtocol
    private let threshold: CGFloat
    
    public var onLoadMore: (() -> Void)?
    
    private var state: LoadMoreState = .idle {
        didSet {
            loadMoreView.loadMoreStateChanged(to: state)
        }
    }
    
    private var isObserving = false
    
    public init(scrollView: UIScrollView, loadMoreView: LoadMoreViewProtocol, threshold: CGFloat = 44.0) {
        self.scrollView = scrollView
        self.loadMoreView = loadMoreView
        self.threshold = threshold
        super.init()
        
        setupView()
        startObserving()
    }
    
    deinit {
        stopObserving()
    }
    
    private func setupView() {
        scrollView?.addSubview(loadMoreView)
        updateFrame()
    }
    
    public func updateFrame() {
        guard let scrollView = scrollView else { return }
        let contentHeight = scrollView.contentSize.height
        // Ensure it's at least at the bottom of the view if content is small
        let y = max(contentHeight, scrollView.bounds.height)
        loadMoreView.frame = CGRect(x: 0, y: y, width: scrollView.bounds.width, height: threshold)
    }
    
    private func startObserving() {
        guard !isObserving, let scrollView = scrollView else { return }
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        isObserving = true
    }
    
    private func stopObserving() {
        guard isObserving, let scrollView = scrollView else { return }
        scrollView.removeObserver(self, forKeyPath: "contentOffset")
        scrollView.removeObserver(self, forKeyPath: "contentSize")
        isObserving = false
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let scrollView = scrollView else { return }
        
        if keyPath == "contentSize" {
            updateFrame()
        } else if keyPath == "contentOffset" {
            checkTriggerLoadMore()
        }
    }
    
    private func checkTriggerLoadMore() {
        guard state == .idle, let scrollView = scrollView else { return }
        
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let offsetY = scrollView.contentOffset.y
        
        // Only trigger if content is taller than view or if we want to support empty list loading
        if contentHeight > scrollViewHeight {
            if offsetY + scrollViewHeight > contentHeight - threshold {
                beginLoading()
            }
        }
    }
    
    public func beginLoading() {
        guard state == .idle else { return }
        state = .loading
        
        // Maintain inset to show loading view
        if let scrollView = scrollView {
            var inset = scrollView.contentInset
            inset.bottom += threshold
            UIView.animate(withDuration: 0.3) {
                scrollView.contentInset = inset
            }
        }
        
        onLoadMore?()
    }
    
    public func endLoading(hasMore: Bool = true) {
        guard state == .loading, let scrollView = scrollView else { return }
        
        if hasMore {
            state = .idle
        } else {
            state = .noMore
        }
        
        var inset = scrollView.contentInset
        inset.bottom -= threshold
        UIView.animate(withDuration: 0.3) {
            scrollView.contentInset = inset
        }
    }
    
    public func reset() {
        state = .idle
    }
}

