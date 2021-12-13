//
//  ContentView.swift
//  Noisier
//
//  Created by Yutaro Muta on 2021/12/13.
//

import SwiftUI
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject private var viewModel: ViewModel = .init()

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 30) {
                VStack {
                    Text("AveragePowerLevel")
                    Text("\(viewModel.averagePowerLevel)Hz")
                }
                VStack {
                    Text("PeakHoldLevel")
                    Text("\(viewModel.peakHoldLevel)Hz")
                }
            }
            .font(.title2)
            Spacer()
            Button {
                viewModel.isRunning.value.toggle()
            } label: {
                Text(viewModel.isRunning.value ? "Stop" : "Start")
                    .font(.title)
            }
            Spacer()
        }
        .padding()
    }
}

private extension ContentView {
    final class ViewModel: NSObject, ObservableObject {
        private let captureSession = AVCaptureSession()
        private var cancellables: [AnyCancellable] = .init()
        private var _averagePowerLevel: PassthroughSubject<Float, Never> = .init()
        private var _peakHoldLevel: PassthroughSubject<Float, Never> = .init()

        private(set) var isRunning: CurrentValueSubject<Bool, Never> = .init(false)
        private(set) var averagePowerLevel: String = "-" {
            didSet {
                objectWillChange.send()
            }
        }
        private(set) var peakHoldLevel: String = "-" {
            didSet {
                objectWillChange.send()
            }
        }

        override init() {
            super.init()

            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                return
            }

            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                }
                let audioOutput = AVCaptureAudioDataOutput()
                let queue = DispatchQueue(label: "com.yutailang0119.Noisier.audio",
                                          qos: .background)
                audioOutput.setSampleBufferDelegate(self, queue: queue)
                if captureSession.canAddOutput(audioOutput) {
                    captureSession.addOutput(audioOutput)
                }
            } catch {
                print("Error")
            }

            _averagePowerLevel
                .removeDuplicates()
                .map { String($0) }
                .receive(on: RunLoop.main)
                .sink { [weak self] in
                    self?.averagePowerLevel = $0
                }
                .store(in: &cancellables)
            _peakHoldLevel
                .removeDuplicates()
                .map { String($0) }
                .receive(on: RunLoop.main)
                .sink { [weak self] in
                    self?.peakHoldLevel = $0
                }
                .store(in: &cancellables)

            isRunning
                .removeDuplicates()
                .sink { [weak self] in
                    if $0 {
                        self?.captureSession.startRunning()
                    } else {
                        self?.captureSession.stopRunning()
                    }
                }
                .store(in: &cancellables)
        }
    }
}

extension ContentView.ViewModel: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        connection.audioChannels.forEach {
            print("\($0.averagePowerLevel) / \($0.peakHoldLevel)")
            _averagePowerLevel.send($0.averagePowerLevel)
            _peakHoldLevel.send($0.peakHoldLevel)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
