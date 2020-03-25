//
//  SKVideoPlayerView.swift
//  SKPhotoBrowser
//
//  Created by KMW on 20/3/2020.
//  Copyright © 2016 suzuki_keishi. All rights reserved.
//

import AVKit
import UIKit

@objc protocol SKVideoPlayerViewDelegate {
    
}

class SKVideoPlayerView: UIView {
    var video: SKPhotoProtocol!
    var player: AVPlayer!
    var playButton: UIButton!
    var playerLayer: AVPlayerLayer!
    var controlView: UIView!
    var isPlaying: Bool = false
    var wasPlayingBeforeSliding: Bool = false
    
    ///Color of the circular control
    var sliderControlColor: UIColor = UIColor.red
    ///Color of the slider minimum track
    var sliderColor: UIColor = UIColor.red
    ///Color of the slider maximum track
    var sliderTractColor: UIColor = UIColor.white
    
    var videoCurrentLengthLabel: UILabel!
    var videoSlider: UISlider!
    var videoTotalLengthLabel: UILabel!
    
    fileprivate var activityIndicatorView: UIActivityIndicatorView!
    
    weak var delegate: SKVideoPlayerViewDelegate?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(frame: CGRect, video: SKPhotoProtocol) {
        self.init()
        self.video = video
        setup()
    }
    
    deinit {
        if let _player = self.player {
            _player.removeObserver(self, forKeyPath: "currentItem.loadedTimeRanges")
            _player.pause()
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "AVPlayerItemDidPlayToEndTimeNotification"), object: _player.currentItem)
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        }
    }
    
    override func layoutSubviews() {
        if let _playerLayer = self.playerLayer,
            let _playButton = self.playButton,
            let _activityIndicatorView = self.activityIndicatorView,
            let _player = self.player {
            // set up frames
            _playerLayer.frame = self.bounds
            _activityIndicatorView.frame = self.bounds

            // autoplay after setting up the views
            _player.play()
            self.isPlaying = true
            _playButton.setImage(nil, for: .normal)
        }
    }
    
    

}


extension SKVideoPlayerView {
    func setup() {
        guard let videoURL = URL(string: self.video.videoURL) else { return }
        let playerItem = AVPlayerItem(url: videoURL)
        
        self.configPlayer(playerItem: playerItem)
    }
    
    func configPlayer(playerItem: AVPlayerItem) {
        self.player = AVPlayer(playerItem: playerItem)
        self.playerLayer = AVPlayerLayer(player: self.player)
        
        //Set the background to clear color so the image undernearth could be shown as cover
        self.playerLayer.backgroundColor = UIColor.clear.cgColor
        self.playerLayer.frame = self.bounds

        self.layer.addSublayer(self.playerLayer)
        self.configActivityIndicator()
        self.setupControlView()
        self.configPlayControls()
        
        self.player.addObserver(self, forKeyPath: "currentItem.loadedTimeRanges", options: .new, context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pausePlayer), name: NSNotification.Name(rawValue: "AVPlayerItemDidPlayToEndTimeNotification"), object: self.player.currentItem)
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
        
    }
    
    func configActivityIndicator() {
        activityIndicatorView = UIActivityIndicatorView(style: .whiteLarge)
        self.addSubview(activityIndicatorView)
        self.activityIndicatorView.startAnimating()
    }
    
    func setupControlView() {
        controlView = UIView.init()
        self.addSubview(controlView)
    }
    
    func configPlayControls() {
        let bundle = Bundle(for: SKPhotoBrowser.self)
        //Config play button
        playButton = UIButton.init(type: .custom)
        playButton.setImage(UIImage(named: "SKPhotoBrowser.bundle/images/PlayButtonOverlayLarge", in: bundle, compatibleWith: nil), for: .normal)
        playButton.setImage(UIImage(named: "SKPhotoBrowser.bundle/images/PlayButtonOverlayLargeTap", in: bundle, compatibleWith: nil), for: .highlighted)
        playButton.addTarget(self, action: #selector(playButtonClick), for: .touchUpInside)
        self.controlView.addSubview(playButton)
        
        //progress
        videoTotalLengthLabel = UILabel()
        videoTotalLengthLabel.text = "00:00"
        videoTotalLengthLabel.textColor = UIColor.white
        videoTotalLengthLabel.font = UIFont.boldSystemFont(ofSize: 14)
        videoTotalLengthLabel.textAlignment = .right
        videoCurrentLengthLabel = UILabel()
        videoCurrentLengthLabel.text = "00:00"
        videoCurrentLengthLabel.textColor = UIColor.white
        videoCurrentLengthLabel.font = UIFont.boldSystemFont(ofSize: 14)
        videoCurrentLengthLabel.textAlignment = .left
        videoSlider = UISlider()
        videoSlider.minimumTrackTintColor = sliderColor
        videoSlider.maximumTrackTintColor = sliderTractColor
        let thumbImage = self.generateSliderThumbImage(size: CGSize(width: 14, height: 14), backgroundColor: sliderControlColor)
        videoSlider.setThumbImage(thumbImage, for: .normal)
        videoSlider.addTarget(self, action: #selector(self.sliderChange), for: .valueChanged)
        videoSlider.addTarget(self, action: #selector(seekingEnd), for: .touchUpInside)
        videoSlider.addTarget(self, action: #selector(seekingEnd), for: .touchUpOutside)
        videoSlider.addTarget(self, action: #selector(seekingStart), for: .touchDown)
        
        self.controlView.addSubview(videoCurrentLengthLabel)
        self.controlView.addSubview(videoTotalLengthLabel)
        self.controlView.addSubview(videoSlider)
        
        self.controlView.isHidden = true
        
    }
    
    func layoutControlView() {
        let videoFrame = self.playerLayer.videoRect
        debugPrint("videoFrame is \(videoFrame)")
        controlView.frame = videoFrame
        self.playButton.frame = controlView.bounds
        
        videoTotalLengthLabel.translatesAutoresizingMaskIntoConstraints = false
        videoCurrentLengthLabel.translatesAutoresizingMaskIntoConstraints = false
        videoSlider.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 9.0, *) {
            videoTotalLengthLabel.rightAnchor.constraint(equalTo: self.controlView.rightAnchor, constant: -8.0).isActive = true
            videoTotalLengthLabel.bottomAnchor.constraint(equalTo: self.controlView.bottomAnchor).isActive = true
            videoTotalLengthLabel.widthAnchor.constraint(equalToConstant: 60.0).isActive = true
            videoTotalLengthLabel.heightAnchor.constraint(equalToConstant: 24.0).isActive = true
            videoCurrentLengthLabel.leftAnchor.constraint(equalTo: self.controlView.leftAnchor, constant: 8.0).isActive = true
            videoCurrentLengthLabel.bottomAnchor.constraint(equalTo: self.controlView.bottomAnchor).isActive = true
            videoCurrentLengthLabel.widthAnchor.constraint(equalToConstant: 60.0).isActive = true
            videoCurrentLengthLabel.heightAnchor.constraint(equalToConstant: 24.0).isActive = true
            videoSlider.leftAnchor.constraint(equalTo: videoCurrentLengthLabel.rightAnchor).isActive = true
            videoSlider.rightAnchor.constraint(equalTo: videoTotalLengthLabel.leftAnchor).isActive = true
            videoSlider.centerYAnchor.constraint(equalTo: self.videoTotalLengthLabel.centerYAnchor).isActive = true
            
        }
        
        self.controlView.isHidden = false
        self.trackPlayProgress()
        
        
    }
    
    private func trackPlayProgress() {
        let interval = CMTime(value: 1, timescale: 2)
        player?.addPeriodicTimeObserver(forInterval: interval, queue: .main, using: { (progressTime) in

            let seconds = CMTimeGetSeconds(progressTime)
            let displaySecondsInt = Int(seconds) % 60
            let secondsString = String(format: "%02d", displaySecondsInt)
            let minutesString = String(format: "%02d", Int(seconds / 60))
            
            self.videoCurrentLengthLabel.text = "\(minutesString):\(secondsString)"
            
            //Move the slider thumb
            if let duration = self.player?.currentItem?.duration {
                let durationSeconds = CMTimeGetSeconds(duration)
                self.videoSlider.value = Float(seconds / durationSeconds)
            }
            
        })
    }
    
    @objc private func sliderChange() {
        if let _player = self.player, let duration = _player.currentItem?.duration {
            let totalSeconds = CMTimeGetSeconds(duration)
            let sliderSeconds = Float64(videoSlider.value) * totalSeconds
            let sliderTime = CMTime(value: Int64(sliderSeconds), timescale: 1)
            _player.seek(to: sliderTime)
        }
    }
    
    @objc private func seekingStart() {
        if self.isPlaying {
            self.player?.pause()
            self.isPlaying = false
            self.wasPlayingBeforeSliding = true
        } else {
            self.wasPlayingBeforeSliding = false
        }
    }
    
    @objc private func seekingEnd() {
        if self.wasPlayingBeforeSliding {
            self.player?.play()
            self.isPlaying = true
        }
    }
    
    @objc func playButtonClick() {
        let currentTime = self.player.currentItem!.currentTime()
        let durationTime = self.player.currentItem!.duration
        
        debugPrint("player rate: \(self.player.rate)")
        if self.player.rate == 0.0 {
            if currentTime.value == durationTime.value {
                //loop if the end is reached
                self.player.currentItem?.seek(to: CMTime(value: 0, timescale: 1))
            }
            self.player.play()
            self.isPlaying = true
            self.playButton.setImage(nil, for: .normal)
        } else {
            self.pausePlayer()
        }
    }
    
    @objc func pausePlayer() {
        self.player?.pause()
        self.isPlaying = false
        let bundle = Bundle(for: SKPhotoBrowser.self)
        playButton.setImage(UIImage(named: "SKPhotoBrowser.bundle/images/PlayButtonOverlayLarge", in: bundle, compatibleWith: nil), for: .normal)
        playButton.setImage(UIImage(named: "SKPhotoBrowser.bundle/images/PlayButtonOverlayLargeTap", in: bundle, compatibleWith: nil), for: .highlighted)
    }
    
    @objc func rotated() {
        self.layoutControlView()
    }
    

    override internal func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "currentItem.loadedTimeRanges" {
            if let _activityIndicatorView = self.activityIndicatorView {
                _activityIndicatorView.stopAnimating()
                
                layoutControlView()
                
                if let duration = player?.currentItem?.duration {
                    let seconds = CMTimeGetSeconds(duration)
                    let secondsText = Int(seconds) % 60
                    let minutesText = String(format: "%02d", Int(seconds) / 60)
                    self.videoTotalLengthLabel.text = "\(minutesText):\(secondsText)"
                }
                
            }
        }
    }

    fileprivate func generateSliderThumbImage(size: CGSize, backgroundColor: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(backgroundColor.cgColor)
        context?.setStrokeColor(UIColor.clear.cgColor)
        let bounds = CGRect(origin: .zero, size: size)
        context?.addEllipse(in: bounds)
        context?.drawPath(using: .fill)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
