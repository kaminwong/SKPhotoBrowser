//
//  SKVideoPlayerView.swift
//  SKPhotoBrowser
//
//  Created by KMW on 20/3/2020.
//  Copyright © 2016 suzuki_keishi. All rights reserved.
//

import AVKit
import UIKit

@objc public protocol SKVideoPlayerViewDelegate: class {
    func videoPlayerDidStartPlaying(videoID: String, videoURLStr: String)
    func videoPlayButtonTapped()
}

open class SKVideoPlayerView: UIView {
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
    var isTrackingPlayProgress: Bool = false
    
    var videoCurrentLengthLabel: UILabel!
    var videoSlider: UISlider!
    var videoTotalLengthLabel: UILabel!
    
    var playerItem: AVPlayerItem!
    private var playerItemContext = 0
    
    ///The delegate is called in the same VC as the browser is called, like following:
    ///guard let page = self.browser.pageDisplayedAtIndex(index) else { return }
    ///page.videoPlayerView.delegate = self
    open weak var delegate: SKVideoPlayerViewDelegate?
    
    fileprivate var activityIndicatorView: UIActivityIndicatorView!
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(frame: CGRect, video: SKPhotoProtocol) {
        self.init()
        self.video = video
        self.setupSKVideoPlayerView()
    }
    
    deinit {
        debugPrint("SKVideoPlayer deinit")
        
        
        if let _player = self.player {
            _player.removeObserver(self, forKeyPath: "currentItem.loadedTimeRanges")
            _player.pause()
            self.video = nil
            self.player = nil
            if let playerItem = self.playerItem {
                playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &playerItemContext)
            }
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "AVPlayerItemDidPlayToEndTimeNotification"), object: _player.currentItem)
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        }
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        if let _playerLayer = self.playerLayer,
            let _playButton = self.playButton,
            let _activityIndicatorView = self.activityIndicatorView,
            let _player = self.player {
            // set up frames
            debugPrint("layout subviews for videoplayerview, self frame is \(self.bounds)")
            _playerLayer.frame = self.bounds
            _activityIndicatorView.frame = self.bounds
            
            debugPrint("video rect is \(_playerLayer.videoRect)")
            
            self.layoutControlView()
            
            if !isTrackingPlayProgress {
                isTrackingPlayProgress = true
                self.trackPlayProgress()
            }
            
            //Disable auto play for now
            // autoplay after setting up the views
//            _player.play()
//            self.isPlaying = true
//            _playButton.setImage(nil, for: .normal)

            
        }
    }
    
    

}


extension SKVideoPlayerView {
    func setupSKVideoPlayerView() {
        guard let videoURL = URL(string: self.video.videoURL) else { return }
        playerItem = AVPlayerItem(url: videoURL)
        
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
        //self.layoutControlView()
        
        //self.player.addObserver(self, forKeyPath: "currentItem.loadedTimeRanges", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &playerItemContext)
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
        controlView.frame = self.bounds
    }
    
    func configPlayControls() {
        let bundle = Bundle(for: SKPhotoBrowser.self)
        //Config play button
        playButton = UIButton.init(type: .custom)
        playButton.setImage(UIImage(named: "SKPhotoBrowser.bundle/images/PlayButtonOverlayLarge", in: bundle, compatibleWith: nil), for: .normal)
        playButton.setImage(UIImage(named: "SKPhotoBrowser.bundle/images/PlayButtonOverlayLargeTap", in: bundle, compatibleWith: nil), for: .highlighted)
        playButton.addTarget(self, action: #selector(playButtonClick), for: .touchUpInside)
        playButton.backgroundColor = UIColor.clear
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

        self.controlView.isHidden = false
        
    }
    
    func layoutControlView() {
        debugPrint("layout control view, self frame is \(self.frame), playerLayer frame is \(self.playerLayer.frame), if called from layoutsubview, they are not expected to be zero. Video rect is \(self.playerLayer.videoRect)")
        
        

        guard self.frame != CGRect.zero,
            self.playerLayer.videoRect != CGRect.zero else { return } //Do not layout controlView if self frame is not set yet
        
        
        var videoFrame = self.playerLayer.videoRect

        if #available(iOS 11.0, *) {
            let guide = self.safeAreaLayoutGuide
            let height = guide.layoutFrame.size.height
            let width = guide.layoutFrame.size.width
            if videoFrame.height > height {
                videoFrame = CGRect(x: videoFrame.origin.x, y: videoFrame.origin.y, width: videoFrame.width, height: height)
            }
            if videoFrame.width > width {
                videoFrame = CGRect(x: videoFrame.origin.x, y: videoFrame.origin.y, width: width, height: videoFrame.height)
            }
        }
        
    

        debugPrint("videoFrame is \(videoFrame), viewFrame is \(self.frame)")
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
        
        


    }
    
    private func trackPlayProgress() {
        let interval = CMTime(value: 1, timescale: 2)
        player?.addPeriodicTimeObserver(forInterval: interval, queue: .main, using: {[weak self] (progressTime) in

            let seconds = CMTimeGetSeconds(progressTime)
            let displaySecondsInt = Int(seconds) % 60
            let secondsString = String(format: "%02d", displaySecondsInt)
            let minutesString = String(format: "%02d", Int(seconds / 60))
            
            self?.videoCurrentLengthLabel.text = "\(minutesString):\(secondsString)"
            
            //Move the slider thumb
            if let duration = self?.player?.currentItem?.duration {
                let durationSeconds = CMTimeGetSeconds(duration)
                self?.videoSlider.value = Float(seconds / durationSeconds)
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
        
        delegate?.videoPlayButtonTapped()
        
        debugPrint("player rate: \(self.player.rate)")
        if self.player.rate == 0.0 {
            if currentTime.value == durationTime.value {
                //loop if the end is reached
                self.player.currentItem?.seek(to: CMTime(value: 0, timescale: 1))
            }
            self.player.play()
            self.isPlaying = true
            let videoURLStr = self.video.videoURL ?? ""
            
            //Call out delegate
            delegate?.videoPlayerDidStartPlaying(videoID: self.video.videoID, videoURLStr: videoURLStr)
            
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
    
    func removePlayer() {
        debugPrint("remove player")
        
        if let playerItem = self.playerItem {
            playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &playerItemContext)
        }
            
        
        if let _player = self.player {
            debugPrint("SKVideoPlayer removePlayer")
            _player.pause()
            
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "AVPlayerItemDidPlayToEndTimeNotification"), object: _player.currentItem)
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
            self.video = nil
            self.player = nil
        }
        
    }
    
    
    @objc func rotated() {
        debugPrint("rotated")
        self.layoutControlView()
    }
    

    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//        if keyPath == "currentItem.loadedTimeRanges" {
//
//        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            var status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            switch status {
            case .readyToPlay:
                print("ready to play")
                debugPrint("2 videoRect here is \(self.playerLayer.videoRect)")
                
                if let _activityIndicatorView = self.activityIndicatorView {
                               _activityIndicatorView.stopAnimating()
                               
                               if let duration = player?.currentItem?.duration {
                                   let seconds = CMTimeGetSeconds(duration)
                                   let secondsText = Int(seconds) % 60
                                   let minutesText = String(format: "%02d", Int(seconds) / 60)
                                   self.videoTotalLengthLabel.text = "\(minutesText):\(secondsText)"
                                   
                                   debugPrint("videoRect here is \(self.playerLayer.videoRect)")
                                   
                                   self.setNeedsLayout()
                                   self.layoutIfNeeded()
                                   
                               }
                               
                           }
                
                
                
                
            case .failed:
                print("video failed to load")
            case .unknown:
                print("player item it not ready yet")
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
