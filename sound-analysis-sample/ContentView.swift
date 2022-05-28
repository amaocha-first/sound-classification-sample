//
//  ContentView.swift
//  sound-analysis-sample
//
//  Created by shota-nishizawa on 2022/05/28.
//

import SwiftUI
import AVFAudio
import SoundAnalysis

struct ContentView: View {
    @StateObject var resultsObserver = ResultsObserver()
    @ObservedObject private var audioManager = AudioManager()
    
    var body: some View {
        VStack {
            Text(resultsObserver.background)
            Text(resultsObserver.female)
            Text(resultsObserver.male)

            Button("Analyze") {
                audioManager.startAudioEngine()
                audioManager.createStreamAnalyzer()
                audioManager.installAudioTap()
            }
        }
        .onAppear {
            audioManager.resultsObserver = self.resultsObserver
        }
    }
}

final class AudioManager: ObservableObject {
    var audioEngine: AVAudioEngine?
    var inputBus: AVAudioNodeBus?
    var inputFormat: AVAudioFormat?
    var streamAnalyzer: SNAudioStreamAnalyzer?
    var resultsObserver: ResultsObserver?
    
    init() {
        
    }

    func startAudioEngine() {
        // Create a new audio engine.
        audioEngine = AVAudioEngine()

        // Get the native audio format of the engine's input bus.
        inputBus = AVAudioNodeBus(0)
        inputFormat = audioEngine!.inputNode.inputFormat(forBus: inputBus!)
        
        do {
            // Start the stream of audio data.
            try audioEngine!.start()
        } catch {
            print("Unable to start AVAudioEngine: \(error.localizedDescription)")
        }
    }
    
    func createStreamAnalyzer() {
        streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat!)
        do {
            let request = try SNClassifySoundRequest(mlModel: VoiceSexClassifier().model)
            try streamAnalyzer!.add(request,
                                    withObserver: resultsObserver!)
        } catch {
            print("Unable to create StreamAnalyzer")
        }
    }
    
    func installAudioTap() {
        audioEngine!.inputNode.installTap(onBus: inputBus!,
                                         bufferSize: 8192,
                                         format: inputFormat!,
                                         block: analyzeAudio(buffer:at:))
    }
    
    private func analyzeAudio(buffer: AVAudioBuffer, at time: AVAudioTime) {
        let analysisQueue = DispatchQueue(label: "com.example.AnalysisQueue")
        analysisQueue.async {
            self.streamAnalyzer!.analyze(buffer,
                                        atAudioFramePosition: time.sampleTime)
        }
    }
}

/// An observer that receives results from a classify sound request.
class ResultsObserver: NSObject, SNResultsObserving, ObservableObject {
    @Published var formattedTime = ""
    @Published var background = ""
    @Published var female = ""
    @Published var male = ""
    
    /// Notifies the observer when a request generates a prediction.
    func request(_ request: SNRequest, didProduce result: SNResult) {
        // Downcast the result to a classification result.
        guard let result = result as? SNClassificationResult else  { return }

        // Get the prediction with the highest confidence.
        guard let classification = result.classifications.first else { return }

        // Convert the confidence to a percentage string.
        
        for classification in result.classifications {
            let percent = classification.confidence * 100.0
            let percentString = String(format: "%.2f%%", percent)
            
            DispatchQueue.main.async { [weak self] in
                if classification.identifier == "background" {
                    self?.background = "\(classification.identifier): \(percentString) confidence.\n"
                } else if classification.identifier == "female" {
                    self?.female = "\(classification.identifier): \(percentString) confidence.\n"
                } else if classification.identifier == "male" {
                    self?.male = "\(classification.identifier): \(percentString) confidence.\n"
                }
            }
        }
    }


    /// Notifies the observer when a request generates an error.
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("The the analysis failed: \(error.localizedDescription)")
    }

    /// Notifies the observer when a request is complete.
    func requestDidComplete(_ request: SNRequest) {
        print("The request completed successfully!")
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
