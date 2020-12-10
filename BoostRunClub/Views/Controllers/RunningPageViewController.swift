//
//  RunningViewController.swift
//  BoostRunClub
//
//  Created by Imho Jang on 2020/11/23.
//

import Combine
import MapKit
import UIKit

extension RunningPageViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = view.bounds.width
        let value = (scrollView.contentOffset.x + width * CGFloat(currPageIdx - 2))
        buttonScale = abs(value / width)
    }

    func scrollViewWillBeginDragging(_: UIScrollView) {
        isDragging = true
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate _: Bool) {
        isDragging = false
    }
}

extension RunningPageViewController {
    func transformBackButton() {
        backButton.transform = CGAffineTransform.identity
            .translatedBy(x: 0, y: buttonScale * distance)
            .scaledBy(x: buttonScale, y: buttonScale)
        pageControl.transform = CGAffineTransform.identity
            .translatedBy(x: 0, y: buttonScale * distance)

        UIView.animate(withDuration: 0) {
            self.pageControl.alpha = 1 - self.buttonScale * 3
        }
    }

    func goBackToMainPage() {
        let direction: UIPageViewController.NavigationDirection = currPageIdx < 1 ? .forward : .reverse

        setViewControllers([pages[1]], direction: direction, animated: true) { _ in
            self.currPageIdx = 1
        }
    }
}

final class RunningPageViewController: UIPageViewController {
    enum Pages: CaseIterable {
        case map, info, splits
    }

    private var pages = [UIViewController]()
    private lazy var pageControl = makePageControl()
    private lazy var backButton = makeBackButton()

    var viewModel: RunningPageViewModelTypes?
    var cancellables = Set<AnyCancellable>()

    var distance: CGFloat = 0
    let buttonHeight: CGFloat = 40
    var currPageIdx = 1
    var isDragging = false
    var buttonScale: CGFloat = 0 {
        didSet {
            if buttonScale > 1 {
                buttonScale = 1
                return
            }
            if isDragging { return }
            transformBackButton()
        }
    }

    init(with viewModel: RunningPageViewModelTypes, viewControllers: [UIViewController]) {
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        self.viewModel = viewModel
        pages = viewControllers
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func bindViewModel() {
        viewModel?.outputs.runningTimeSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.backButton.setTitle($0, for: .normal) }
            .store(in: &cancellables)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configurePageViewController()
        configureSubViews()
        bindViewModel()
        buttonScale = 0

        view.layoutIfNeeded()
        distance = view.bounds.height - pageControl.center.y - buttonHeight / 2 - 30
    }

    deinit {
        print("[\(Date())] 🍎ViewController🍏 \(Self.self) deallocated.")
    }
}

extension RunningPageViewController {
    @objc func didTabBackButton() {
        goBackToMainPage()
    }

    @objc func panGestureAction() {
        transformBackButton()
    }
}

extension RunningPageViewController {
    func configurePageViewController() {
        dataSource = self
        delegate = self
        setViewControllers([pages[1]], direction: .forward, animated: true, completion: nil)

        let gesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction))
        gesture.delegate = self
        view.addGestureRecognizer(gesture)

        view.subviews.forEach { view in
            if let scrollView = view as? UIScrollView {
                scrollView.delegate = self
            }
        }
    }

    func configureSubViews() {
        view.addSubview(pageControl)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        view.addSubview(backButton)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.centerYAnchor.constraint(equalTo: pageControl.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 100),
            backButton.heightAnchor.constraint(equalToConstant: buttonHeight),
        ])
    }

    func makePageControl() -> UIPageControl {
        let pageControl = UIPageControl()
        pageControl.pageIndicatorTintColor = .gray
        pageControl.currentPageIndicatorTintColor = .black
        pageControl.numberOfPages = Pages.allCases.count
        pageControl.currentPage = 1
        pageControl.isUserInteractionEnabled = false
        return pageControl
    }

    func makeBackButton() -> UIButton {
        let button = UIButton()
        button.backgroundColor = .systemGreen
        button.addTarget(self, action: #selector(didTabBackButton), for: .touchUpInside)
        return button
    }
}

extension RunningPageViewController: UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating _: Bool,
        previousViewControllers _: [UIViewController],
        transitionCompleted _: Bool
    ) {
        if let viewControllers = pageViewController.viewControllers {
            if let viewControllerIndex = pages.firstIndex(of: viewControllers[0]) {
                pageControl.currentPage = viewControllerIndex
                currPageIdx = viewControllerIndex
            }
        }
    }
}

extension RunningPageViewController: UIPageViewControllerDataSource {
    func pageViewController(
        _: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    )
        -> UIViewController?
    {
        if let viewControllerIndex = pages.firstIndex(of: viewController) {
            if viewControllerIndex == 0 {
                return nil
            } else {
                return pages[viewControllerIndex - 1]
            }
        }
        return nil
    }

    func pageViewController(
        _: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    )
        -> UIViewController?
    {
        if let viewControllerIndex = pages.firstIndex(of: viewController) {
            if viewControllerIndex < pages.count - 1 {
                return pages[viewControllerIndex + 1]
            } else {
                return nil
            }
        }
        return nil
    }
}

extension RunningPageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
    )
        -> Bool
    {
        true
    }
}
