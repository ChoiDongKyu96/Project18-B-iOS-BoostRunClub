//
//  RunningInfoViewModel.swift
//  BoostRunClub
//
//  Created by 조기현 on 2020/11/25.
//

import Combine
import Foundation

protocol RunningInfoViewModelTypes: AnyObject {
    var inputs: RunningInfoViewModelInputs { get }
    var outputs: RunningInfoViewModelOutputs { get }
}

protocol RunningInfoViewModelInputs {
    func didTapPauseButton()
    func didTapRunData(index: Int)
    func viewDidAppear()
}

protocol RunningInfoViewModelOutputs {
    typealias RunningInfoTypeSubject = CurrentValueSubject<RunningInfo, Never>

    var runningInfoObservables: [RunningInfoTypeSubject] { get }
    var runningInfoTapAnimation: PassthroughSubject<Int, Never> { get }
    var initialAnimation: PassthroughSubject<Void, Never> { get }
    var resumeAnimation: PassthroughSubject<Void, Never> { get }
    var showPausedRunningSignal: PassthroughSubject<Void, Never> { get }
}

class RunningInfoViewModel: RunningInfoViewModelInputs, RunningInfoViewModelOutputs {
    private var cancellables = Set<AnyCancellable>()

    private var possibleTypes: [RunningInfoType: String]
    let runningDataProvider: RunningServiceType

    init(runningDataProvider: RunningServiceType) {
        // TODO: GOALTYPE - SPEED 제거
        possibleTypes = RunningInfoType.getPossibleTypes(from: .none)
            .reduce(into: [:]) { $0[$1] = $1.initialValue }

        self.runningDataProvider = runningDataProvider

        runningDataProvider.dashBoard.runningSubject
            .sink { [weak self] data in
                self?.runningInfoObservables.forEach {
                    let value: String
                    switch $0.value.type {
                    case .kilometer:
                        value = String(format: "%.2f", data.distance / 1000)
                    case .pace:
                        value = String(format: "%d'%d\"", data.pace / 60, data.pace % 60)
                    case .averagePace:
                        value = String(format: "%d'%d\"", data.avgPace / 60, data.avgPace % 60)
                    case .calorie:
                        value = data.calorie <= 0 ? "--" : String(data.calorie)
                    case .cadence:
                        value = data.cadence <= 0 ? "--" : String(data.cadence)
                    case .time, .interval, .bpm, .meter:
                        return
                    }
                    $0.send(RunningInfo(type: $0.value.type, value: value))
                }
            }
            .store(in: &cancellables)

        runningDataProvider.dashBoard.runningTime
            .map { $0.simpleFormattedString }
            .sink { [weak self] timeString in
                self?.possibleTypes[.time] = timeString

                self?.runningInfoObservables.forEach {
                    if $0.value.type == .time {
                        $0.send(RunningInfo(type: .time, value: timeString))
                    }
                }
            }.store(in: &cancellables)

        runningDataProvider.runningState
            .sink { [weak self] currentMotionType in
                if currentMotionType == .standing {
                    self?.showPausedRunningSignal.send()
                }
            }.store(in: &cancellables)
    }

    deinit {
        print("[Memory \(Date())] 🌙ViewModel⭐️ \(Self.self) deallocated.")
    }

    // MARK: Inputs

    func didTapPauseButton() {
        showPausedRunningSignal.send()
        runningDataProvider.pause()
    }

    func didTapRunData(index: Int) {
        var nextType = runningInfoObservables[index].value.type.circularNext()
        nextType = possibleTypes[nextType] != nil ? nextType : RunningInfoType.allCases[0]
        runningInfoObservables[index].send(
            RunningInfo(
                type: nextType,
                value: possibleTypes[nextType, default: nextType.initialValue]
            )
        )
        runningInfoTapAnimation.send(index)
    }

    func viewDidAppear() {
        if runningDataProvider.isRunning {
            resumeAnimation.send()
        } else {
            runningDataProvider.start()
            initialAnimation.send()
        }
    }

    // MARK: Outputs

    var runningInfoObservables = [
        RunningInfoTypeSubject(RunningInfo(type: .time)),
        RunningInfoTypeSubject(RunningInfo(type: .pace)),
        RunningInfoTypeSubject(RunningInfo(type: .averagePace)),
        RunningInfoTypeSubject(RunningInfo(type: .kilometer)),
    ]
    var runningInfoTapAnimation = PassthroughSubject<Int, Never>()
    var initialAnimation = PassthroughSubject<Void, Never>()
    var resumeAnimation = PassthroughSubject<Void, Never>()
    var showPausedRunningSignal = PassthroughSubject<Void, Never>()
}

// MARK: - Types

extension RunningInfoViewModel: RunningInfoViewModelTypes {
    var inputs: RunningInfoViewModelInputs { self }
    var outputs: RunningInfoViewModelOutputs { self }
}
