import Foundation
import AVFoundation

class AudioPlayerManager: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var completionHandler: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    func play(url: URL, completion: (() -> Void)? = nil) {
        // Stop any existing playback
        stop()
        
        // Try direct playback if the URL is local
        if url.isFileURL {
            playLocalFile(url: url, completion: completion)
            return
        }
        
        // Download and play remote URL
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print("Error downloading audio: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion?()
                }
                return
            }
            
            DispatchQueue.main.async {
                self.playData(data: data, completion: completion)
            }
        }.resume()
    }
    
    private func playLocalFile(url: URL, completion: (() -> Void)?) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            completionHandler = completion
            audioPlayer?.play()
        } catch {
            print("Error playing local audio: \(error)")
            completion?()
        }
    }
    
    private func playData(data: Data, completion: (() -> Void)?) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            completionHandler = completion
            audioPlayer?.play()
        } catch {
            print("Error playing audio data: \(error)")
            completion?()
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        completionHandler = nil
    }
    
    func isPlaying() -> Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.completionHandler?()
            self?.completionHandler = nil
        }
    }
} 