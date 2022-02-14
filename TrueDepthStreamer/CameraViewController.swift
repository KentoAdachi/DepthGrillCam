/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Contains view controller code for previewing live-captured content.
 */

import UIKit
import AVFoundation
import CoreVideo
import MobileCoreServices
import Accelerate

import CoreML
import Vision

import VideoToolbox

import MediaPlayer
import AVKit

@available(iOS 14.0, *)
class CameraViewController: UIViewController, AVCaptureDataOutputSynchronizerDelegate {
    
    // MARK: - Properties
    @IBOutlet weak var recordButton: UIButton!
    
    @IBOutlet weak private var resumeButton: UIButton!
    
    @IBOutlet weak private var cameraUnavailableLabel: UILabel!
    
    @IBOutlet weak private var jetView: PreviewMetalView!
    
    @IBOutlet weak private var depthSmoothingSwitch: UISwitch!
    
    @IBOutlet weak private var mixFactorSlider: UISlider!
    
    @IBOutlet weak private var touchDepth: UILabel!
    
    @IBOutlet weak var autoPanningSwitch: UISwitch!
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private var setupResult: SessionSetupResult = .success
    
    private let session = AVCaptureSession()
    
    private var isSessionRunning = false
    
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem)
    private var videoDeviceInput: AVCaptureDeviceInput!
    
    private let dataOutputQueue = DispatchQueue(label: "video data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    private let videoDepthMixer = VideoMixer()
    
    private let videoDepthConverter = DepthToJETConverter()
    //    private let videoDepthConverter = DepthToGrayscaleConverter()
    
    private var renderingEnabled = true
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera],
                                                                               mediaType: .video,
                                                                               position: .front)
    
    private var statusBarOrientation: UIInterfaceOrientation = .portrait
    
    private var touchDetected = false
    
    private var touchCoordinates = CGPoint(x: 0, y: 0)
    
//    @IBOutlet weak private var cloudView: PointCloudMetalView!
    
    @IBOutlet weak private var cloudToJETSegCtrl: UISegmentedControl!
    
    @IBOutlet weak private var smoothDepthLabel: UILabel!
    
    
    private var lastScale = Float(1.0)
    
    private var lastScaleDiff = Float(0.0)
    
    private var lastZoom = Float(0.0)
    
    private var lastXY = CGPoint(x: 0, y: 0)
    
//    private var JETEnabled = true
    
    private var viewFrameSize = CGSize()
    
    private var autoPanningIndex = Int(0) // start with auto-panning on
    
    //カスタム
    private var videoWriter : AVAssetWriter? = nil
    private var depthWriter : AVAssetWriter? = nil
    private var videoWriterInput : AVAssetWriterInput? = nil
    private var depthWriterInput : AVAssetWriterInput? = nil
    
    private var currentSampleBuffer : CMSampleBuffer? = nil
    
    @IBOutlet weak var WeightField: UITextField!
    @IBOutlet weak var ClassField: UITextField!
    @IBOutlet weak var MassLabel: UILabel!
    @IBOutlet weak var AverageDepthLabel: UILabel!
    @IBOutlet weak var PixelCountLabel: UILabel!
    @IBOutlet weak var CalorieLabel: UILabel!
    @IBOutlet weak var CategoryLabel: UILabel!
    @IBOutlet weak var ImageModeSwitch: UISwitch!
    
    var segmentator : Segmentator? = nil
    
    private var isRecording : Bool = false
    private var durationSavingImage : Float = 0.2
    private var isCooltimeSavingImage : Bool = true
    private var coolTimeSavingImage : Timer? = nil
    private var depthImageFileName : String = ""
    private var depthImageCounter : Int = 0
    private var singleImageFileName : String = ""
    //あとでパス追加
    private let singleImageSavingPath : URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Image")
    
    private let depthImageSavingPath : URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Depth")
    
    var eatingActionRecognizer : EatingActionRecognizer?
    
    //TODO: 表示位置を補正する必要がある
    private var enableTouchDepth : Bool = false
    
    var calorieEstimator : CalorieEstimator? = nil
    var currentCalorie : Float = 0
    
    private (set) var currentState : String = "segmentation"
    var isCooltime : Bool = false
    
    var boxView : BoxView? = nil
    var foodAverageDepth : Float = 0
    
//    食べるたびにリセット
    var totalFoodCalorieInstance : Float = 0
    var totalFoodCountInstance : Int = 0
    
    @IBOutlet weak var totalCalorieLabel: UILabel!
    
    @IBOutlet weak var foodCountLabel: UILabel!
    
    @IBOutlet weak var StatusLabel: UILabel!
    // MARK: - View Controller Life Cycle
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.boxView = BoxView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height))
        self.boxView!.isOpaque = false
        self.boxView!.isUserInteractionEnabled = false
        self.view.addSubview(boxView!)
        
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: {(timer) in
            self.setCurrentState(state: "segmentation")
        })
        
        self.eatingActionRecognizer = EatingActionRecognizer(controller: self)
        self.calorieEstimator = CalorieEstimator(controller: self)
        self.segmentator = Segmentator(cameraViewController: self)
        
        //label transforms
//        self.MassLabel.transform = self.MassLabel.transform.rotated(by: -3.14/2)
//        self.AverageDepthLabel.transform = self.AverageDepthLabel.transform.rotated(by: -3.14/2)
//        self.PixelCountLabel.transform = self.PixelCountLabel.transform.rotated(by: -3.14/2)
//        self.CalorieLabel.transform = self.CalorieLabel.transform.rotated(by: -3.14/2)
//        self.CategoryLabel.transform = self.CategoryLabel.transform.rotated(by: -3.14/2)
//        self.totalCalorieLabel.transform = self.totalCalorieLabel.transform.rotated(by: -3.14/2)
//        self.foodCountLabel.transform = self.foodCountLabel.transform.rotated(by: -3.14/2)
//        self.StatusLabel.transform = self.StatusLabel.transform.rotated(by: -.pi/2)
        
//        let upperRight = CGPoint(x: self.view.bounds.width * 0.05, y: self.view.bounds.height * 0.2)
//        let upperLeft = CGPoint(x: self.view.bounds.width * 0.05, y: self.view.bounds.height * 0.6)
//        let lowerLeft = CGPoint(x: self.view.bounds.width * 0.7, y: self.view.bounds.height * 0.6)
//        self.StatusLabel.frame.origin = upperRight
//        self.totalCalorieLabel.frame.origin = upperLeft + CGPoint(x: 50, y: 0)
//        self.CalorieLabel.frame.origin = upperRight + CGPoint(x: 60,y: 0)
//        self.MassLabel.frame.origin = upperLeft
//        self.CategoryLabel.frame.origin = upperRight + CGPoint(x: 30,y: 0)
//        self.MassLabel.frame.origin = lowerLeft
//        self.PixelCountLabel.frame.origin = lowerLeft + CGPoint(x: 20, y: 0)
//        self.AverageDepthLabel.frame.origin = lowerLeft + CGPoint(x: 40, y: 0)
        
        viewFrameSize = self.view.frame.size
        
        let tapGestureJET = UITapGestureRecognizer(target: self, action: #selector(focusAndExposeTap))
        jetView.addGestureRecognizer(tapGestureJET)
        
        let pressGestureJET = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressJET))
        pressGestureJET.minimumPressDuration = 0.05
        pressGestureJET.cancelsTouchesInView = false
        jetView.addGestureRecognizer(pressGestureJET)
        
        // switch is hidden
        self.depthDataOutput.isFilteringEnabled = self.depthSmoothingSwitch.isOn
//        self.depthDataOutput.isFilteringEnabled = false
        self.jetView.isHidden = false

        
//        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
//        cloudView.addGestureRecognizer(pinchGesture)
//
//        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
//        doubleTapGesture.numberOfTapsRequired = 2
//        doubleTapGesture.numberOfTouchesRequired = 1
//        cloudView.addGestureRecognizer(doubleTapGesture)
//
//        let rotateGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate))
//        cloudView.addGestureRecognizer(rotateGesture)
//
//        let panOneFingerGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanOneFinger))
//        panOneFingerGesture.maximumNumberOfTouches = 1
//        panOneFingerGesture.minimumNumberOfTouches = 1
//        cloudView.addGestureRecognizer(panOneFingerGesture)
        
        cloudToJETSegCtrl.selectedSegmentIndex = 0
        
        // Check video authorization status, video access is required
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera
            break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant video access
             We suspend the session queue to delay session setup until the access request has completed
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access
            setupResult = .notAuthorized
        }
        
        /*
         Setup the capture session.
         In general it is not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Why not do all of this on the main queue?
         Because AVCaptureSession.startRunning() is a blocking call which can
         take a long time. We dispatch session setup to the sessionQueue so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let interfaceOrientation = UIApplication.shared.statusBarOrientation
//        let interfaceOrientation = self.view.window?.window!.windowScene!.interfaceOrientation
        statusBarOrientation = interfaceOrientation
        
        let initialThermalState = ProcessInfo.processInfo.thermalState
        if initialThermalState == .serious || initialThermalState == .critical {
            showThermalState(state: initialThermalState)
        }
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded
                self.addObservers()
                let videoOrientation = self.videoDataOutput.connection(with: .video)!.videoOrientation
                let videoDevicePosition = self.videoDeviceInput.device.position
                let rotation = PreviewMetalView.Rotation(with: interfaceOrientation,
                                                         videoOrientation: videoOrientation,
                                                         cameraPosition: videoDevicePosition)
                self.jetView.mirroring = (videoDevicePosition == .front)
                if let rotation = rotation {
                    self.jetView.rotation = rotation
                }
                self.dataOutputQueue.async {
                    self.renderingEnabled = true
                }
                
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let message = NSLocalizedString("TrueDepthStreamer doesn't have permission to use the camera, please change privacy settings",
                                                    comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "TrueDepthStreamer", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                  options: [:],
                                                  completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    self.cameraUnavailableLabel.isHidden = false
                    self.cameraUnavailableLabel.alpha = 0.0
                    UIView.animate(withDuration: 0.25) {
                        self.cameraUnavailableLabel.alpha = 1.0
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        dataOutputQueue.async {
            self.renderingEnabled = false
        }
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    @objc
    func didEnterBackground(notification: NSNotification) {
        // Free up resources
        dataOutputQueue.async {
            self.renderingEnabled = false
            self.videoDepthMixer.reset()
            self.videoDepthConverter.reset()
            self.jetView.pixelBuffer = nil
            self.jetView.flushTextureCache()
        }
    }
    
    @objc
    func willEnterForground(notification: NSNotification) {
        dataOutputQueue.async {
            self.renderingEnabled = true
        }
    }
    
    // You can use this opportunity to take corrective action to help cool the system down.
    @objc
    func thermalStateChanged(notification: NSNotification) {
        if let processInfo = notification.object as? ProcessInfo {
            showThermalState(state: processInfo.thermalState)
        }
    }
    
    func showThermalState(state: ProcessInfo.ThermalState) {
        DispatchQueue.main.async {
            var thermalStateString = "UNKNOWN"
            if state == .nominal {
                thermalStateString = "NOMINAL"
            } else if state == .fair {
                thermalStateString = "FAIR"
            } else if state == .serious {
                thermalStateString = "SERIOUS"
            } else if state == .critical {
                thermalStateString = "CRITICAL"
            }
            
            let message = NSLocalizedString("Thermal state: \(thermalStateString)", comment: "Alert message when thermal state has changed")
            let alertController = UIAlertController(title: "TrueDepthStreamer", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
//    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//        super.viewWillTransition(to: size, with: coordinator)
//
//        coordinator.animate(
//            alongsideTransition: { _ in
//                let interfaceOrientation = UIApplication.shared.statusBarOrientation
//                self.statusBarOrientation = interfaceOrientation
//                self.sessionQueue.async {
//                    /*
//                     The photo orientation is based on the interface orientation. You could also set the orientation of the photo connection based
//                     on the device orientation by observing UIDeviceOrientationDidChangeNotification.
//                     */
//                    let videoOrientation = self.videoDataOutput.connection(with: .video)!.videoOrientation
//                    if let rotation = PreviewMetalView.Rotation(with: interfaceOrientation, videoOrientation: videoOrientation,
//                                                                cameraPosition: self.videoDeviceInput.device.position) {
//                        self.jetView.rotation = rotation
//                    }
//                }
//            }, completion: nil
//        )
//    }
    
    // MARK: - KVO and Notifications
    
    private var sessionRunningContext = 0
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateChanged),
                                               name: ProcessInfo.thermalStateDidChangeNotification,	object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError),
                                               name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        
        session.addObserver(self, forKeyPath: "running", options: NSKeyValueObservingOptions.new, context: &sessionRunningContext)
        
        /*
         A session can only run when the app is full screen. It will be interrupted
         in a multi-app layout, introduced in iOS 9, see also the documentation of
         AVCaptureSessionInterruptionReason. Add observers to handle these session
         interruptions and show a preview is paused message. See the documentation
         of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
         */
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted),
                                               name: NSNotification.Name.AVCaptureSessionWasInterrupted,
                                               object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded),
                                               name: NSNotification.Name.AVCaptureSessionInterruptionEnded,
                                               object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange),
                                               name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                                               object: videoDeviceInput.device)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        session.removeObserver(self, forKeyPath: "running", context: &sessionRunningContext)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if context != &sessionRunningContext {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: - Session Management
    
    // Call this on the session queue
    // デバイスと入力を結びつけるsessionの定義
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        let defaultVideoDevice: AVCaptureDevice? = videoDeviceDiscoverySession.devices.first
        
        guard let videoDevice = defaultVideoDevice else {
            print("Could not find any video device")
            setupResult = .configurationFailed
            return
        }
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }
        
        session.beginConfiguration()
        
        session.sessionPreset = AVCaptureSession.Preset.vga640x480
        
        // Add a video input
        guard session.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)
        
        // Add a video data output
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        } else {
            print("Could not add video data output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add a depth data output
        if session.canAddOutput(depthDataOutput) {
            session.addOutput(depthDataOutput)
            depthDataOutput.isFilteringEnabled = false
            if let connection = depthDataOutput.connection(with: .depthData) {
                connection.isEnabled = true
            } else {
                print("No AVCaptureConnection")
            }
        } else {
            print("Could not add depth data output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Search for highest resolution with half-point depth values
        let depthFormats = videoDevice.activeFormat.supportedDepthDataFormats
        let filtered = depthFormats.filter({
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
        })
        let selectedFormat = filtered.max(by: {
            first, second in CMVideoFormatDescriptionGetDimensions(first.formatDescription).width < CMVideoFormatDescriptionGetDimensions(second.formatDescription).width
        })
        
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeDepthDataFormat = selectedFormat
            videoDevice.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
        // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
        outputSynchronizer!.setDelegate(self, queue: dataOutputQueue)
        session.commitConfiguration()
    }
    
    private func focus(with focusMode: AVCaptureDevice.FocusMode,
                       exposureMode: AVCaptureDevice.ExposureMode,
                       at devicePoint: CGPoint,
                       monitorSubjectAreaChange: Bool) {
        sessionQueue.async {
            let videoDevice = self.videoDeviceInput.device
            
            do {
                try videoDevice.lockForConfiguration()
                if videoDevice.isFocusPointOfInterestSupported && videoDevice.isFocusModeSupported(focusMode) {
                    videoDevice.focusPointOfInterest = devicePoint
                    videoDevice.focusMode = focusMode
                }
                
                if videoDevice.isExposurePointOfInterestSupported && videoDevice.isExposureModeSupported(exposureMode) {
                    videoDevice.exposurePointOfInterest = devicePoint
                    videoDevice.exposureMode = exposureMode
                }
                
                videoDevice.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                videoDevice.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
    
    @IBAction private func changeMixFactor(_ sender: UISlider) {
        let mixFactor = sender.value
        
        dataOutputQueue.async {
            self.videoDepthMixer.mixFactor = mixFactor
        }
    }
    
    @IBAction private func changeDepthSmoothing(_ sender: UISwitch) {
        let smoothingEnabled = sender.isOn
        
        sessionQueue.async {
            self.depthDataOutput.isFilteringEnabled = smoothingEnabled
        }
    }
    
//    @IBAction func changeCloudToJET(_ sender: UISegmentedControl) {
//        JETEnabled = (sender.selectedSegmentIndex == 0)
//
//        sessionQueue.sync {
//            if JETEnabled {
//                self.depthDataOutput.isFilteringEnabled = self.depthSmoothingSwitch.isOn
//            } else {
//                self.depthDataOutput.isFilteringEnabled = false
//            }
//
////            self.cloudView.isHidden = JETEnabled
//            self.jetView.isHidden = !JETEnabled
//        }
//    }
    
    @IBAction private func focusAndExposeTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: jetView)
        guard let texturePoint = jetView.texturePointForView(point: location) else {
            return
        }
        
        let textureRect = CGRect(origin: texturePoint, size: .zero)
        let deviceRect = videoDataOutput.metadataOutputRectConverted(fromOutputRect: textureRect)
        focus(with: .autoFocus, exposureMode: .autoExpose, at: deviceRect.origin, monitorSubjectAreaChange: true)
    }
    
    @objc
    func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    @objc
    func sessionWasInterrupted(notification: NSNotification) {
        // In iOS 9 and later, the userInfo dictionary contains information on why the session was interrupted.
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
           let reasonIntegerValue = userInfoValue.integerValue,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted with reason \(reason)")
            
            if reason == .videoDeviceInUseByAnotherClient {
                // Simply fade-in a button to enable the user to try to resume the session running.
                resumeButton.isHidden = false
                resumeButton.alpha = 0.0
                UIView.animate(withDuration: 0.25) {
                    self.resumeButton.alpha = 1.0
                }
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                // Simply fade-in a label to inform the user that the camera is unavailable.
                cameraUnavailableLabel.isHidden = false
                cameraUnavailableLabel.alpha = 0.0
                UIView.animate(withDuration: 0.25) {
                    self.cameraUnavailableLabel.alpha = 1.0
                }
            }
        }
    }
    
    @objc
    func sessionInterruptionEnded(notification: NSNotification) {
        if !resumeButton.isHidden {
            UIView.animate(withDuration: 0.25,
                           animations: {
                self.resumeButton.alpha = 0
            }, completion: { _ in
                self.resumeButton.isHidden = true
            }
            )
        }
        if !cameraUnavailableLabel.isHidden {
            UIView.animate(withDuration: 0.25,
                           animations: {
                self.cameraUnavailableLabel.alpha = 0
            }, completion: { _ in
                self.cameraUnavailableLabel.isHidden = true
            }
            )
        }
    }
    
    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return
        }
        
        let error = AVError(_nsError: errorValue)
        print("Capture session runtime error: \(error)")
        
        /*
         Automatically try to restart the session running if media services were
         reset and the last start running succeeded. Otherwise, enable the user
         to try to resume the session running.
         */
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                } else {
                    DispatchQueue.main.async {
                        self.resumeButton.isHidden = false
                    }
                }
            }
        } else {
            resumeButton.isHidden = false
        }
    }
    
    @IBAction private func resumeInterruptedSession(_ sender: UIButton) {
        sessionQueue.async {
            /*
             The session might fail to start running. A failure to start the session running will be communicated via
             a session runtime error notification. To avoid repeatedly failing to start the session
             running, we only try to restart the session running in the session runtime error handler
             if we aren't trying to resume the session running.
             */
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
            if !self.session.isRunning {
                DispatchQueue.main.async {
                    let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
                    let alertController = UIAlertController(title: "TrueDepthStreamer", message: message, preferredStyle: .alert)
                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            } else {
                DispatchQueue.main.async {
                    self.resumeButton.isHidden = true
                }
            }
        }
    }
    
    func setCurrentState(state:String){
        DispatchQueue.main.async {
            self.StatusLabel.text = state
        }
        
        self.currentState = state
    }
    // MARK: - Point cloud view gestures
    
//    @IBAction private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
//        if gesture.numberOfTouches != 2 {
//            return
//        }
//        if gesture.state == .began {
//            lastScale = 1
//        } else if gesture.state == .changed {
//            let scale = Float(gesture.scale)
//            let diff: Float = scale - lastScale
//            let factor: Float = 1e3
//            if scale < lastScale {
//                lastZoom = diff * factor
//            } else {
//                lastZoom = diff * factor
//            }
//            DispatchQueue.main.async {
//                self.autoPanningSwitch.isOn = false
//                self.autoPanningIndex = -1
//            }
//            cloudView.moveTowardCenter(lastZoom)
//            lastScale = scale
//        } else if gesture.state == .ended {
//        } else {
//        }
//    }
    
//    @IBAction private func handlePanOneFinger(gesture: UIPanGestureRecognizer) {
//        if gesture.numberOfTouches != 1 {
//            return
//        }
//
//        if gesture.state == .began {
//            let pnt: CGPoint = gesture.translation(in: cloudView)
//            lastXY = pnt
//        } else if (.failed != gesture.state) && (.cancelled != gesture.state) {
//            let pnt: CGPoint = gesture.translation(in: cloudView)
//            DispatchQueue.main.async {
//                self.autoPanningSwitch.isOn = false
//                self.autoPanningIndex = -1
//            }
//            cloudView.yawAroundCenter(Float((pnt.x - lastXY.x) * 0.1))
//            cloudView.pitchAroundCenter(Float((pnt.y - lastXY.y) * 0.1))
//            lastXY = pnt
//        }
//    }
    
//    @IBAction private func handleDoubleTap(gesture: UITapGestureRecognizer) {
//        DispatchQueue.main.async {
//            self.autoPanningSwitch.isOn = false
//            self.autoPanningIndex = -1
//        }
//        cloudView.resetView()
//    }
//
//    @IBAction private func handleRotate(gesture: UIRotationGestureRecognizer) {
//        if gesture.numberOfTouches != 2 {
//            return
//        }
//
//        if gesture.state == .changed {
//            let rot = Float(gesture.rotation)
//            DispatchQueue.main.async {
//                self.autoPanningSwitch.isOn = false
//                self.autoPanningIndex = -1
//            }
//            cloudView.rollAroundCenter(rot * 60)
//            gesture.rotation = 0
//        }
//    }
    
    // MARK: - JET view Depth label gesture
    
    func inv(point:CGPoint)->CGPoint{
        return CGPoint(x: UIScreen.main.bounds.size.width - point.x, y: point.y)
    }
    
    @IBAction private func handleLongPressJET(gesture: UILongPressGestureRecognizer) {
        
        switch gesture.state {
        case .began:
            touchDetected = true
            let pnt: CGPoint = gesture.location(in: self.jetView)
            touchCoordinates = inv(point: pnt)
        case .changed:
            let pnt: CGPoint = gesture.location(in: self.jetView)
            touchCoordinates = inv(point: pnt)
        case .possible, .ended, .cancelled, .failed:
            touchDetected = false
            DispatchQueue.main.async {
                self.touchDepth.text = ""
            }
        @unknown default:
            print("Unknown gesture state.")
            touchDetected = false
        }
        
    }
    
    @IBAction func didAutoPanningChange(_ sender: Any) {
        if autoPanningSwitch.isOn {
            self.autoPanningIndex = 0
        } else {
            self.autoPanningIndex = -1
        }
    }
    
    // MARK: - Handle Segmentation
    func handleSegmentation(depthPixelBuffer: CVPixelBuffer, videoPixelBuffer: CVPixelBuffer, sampleBuffer : CMSampleBuffer)->Bool{
        var cgImageWrapper : CGImage?
        VTCreateCGImageFromCVPixelBuffer(videoPixelBuffer, options: nil, imageOut: &cgImageWrapper)
        guard let videoImage : CGImage = cgImageWrapper else {return false}
        
        guard let seg = self.segmentator else {
            print("no segmentator")
            return false
        }
        if(seg.isSegmentable){
            seg.predict(originalImage: videoImage)
        }
        return true
    }
    
//    func getMask()->CGImage?{
//        return self.segmentator?.getMask()
//    }
    
    // MARK: - Handle Calorie Estimation
    func handleCalorieEstimation(image:CVPixelBuffer,depth:CVPixelBuffer,mask:MLMultiArray){
        let category = self.segmentator?.category
        let pixelcount = self.segmentator?.pixelcount
        let avedepth = (self.calorieEstimator?.caliculateAverageDepth(depthFrame: depth, mask: mask))!
        self.foodAverageDepth = avedepth
        let normfactor: Float = 0.1
        let mass : Float = (self.calorieEstimator?.predictMass(pixelCount: pixelcount!, aveDepth: avedepth*normfactor,category: category!))! * 0.1
        let calorie : Float = (self.calorieEstimator?.convertMassToCalorie(mass: mass, category: category!))!
    
        var categoryText : String = "nil"
        switch category {
        case 1:
            categoryText = "焼き肉"
        case 2:
            categoryText = "ピーマン"
        case 3:
            categoryText = "にんじん"
        case 4:
            categoryText = "かぼちゃ"
        case 5:
            categoryText = "白米"
        default:
            categoryText = "未検出"
        }
        
        DispatchQueue.main.async {
            self.PixelCountLabel.text = String(pixelcount!)
            self.AverageDepthLabel.text = String(avedepth)
            self.MassLabel.text = String(format: "%.1f",mass) + "g"
            self.CalorieLabel.text = String(format: "%.1f",calorie) + "kcal"
            self.currentCalorie = calorie
            self.CategoryLabel.text = categoryText
            self.totalFoodCalorieInstance += calorie
            self.totalFoodCountInstance += 1
        }
        
        
        
        
    }
    
    
    // MARK: - Handle Eating Action
    func handleEatingAction(image:CVPixelBuffer,mask:MLMultiArray, depth : CVPixelBuffer){
        //単体実行可能フレームであれば分岐
        //timer使って書き直す

        if self.eatingActionRecognizer!.isFoodTrackable{
            self.eatingActionRecognizer!.isFoodTrackable = false
            if !self.eatingActionRecognizer!.isFoodTracking{
                //first
                self.eatingActionRecognizer!.startTracking(frame: image, boundingbox: (self.segmentator?.boundingBox)!)

            }else{
                //continue
                self.eatingActionRecognizer!.continueTracking(frame: image)

                
            }
            
        }
        
        
        //セグメンテーションが更新されたかどうかで分岐
        DispatchQueue.global(qos: .utility).async {
            if self.eatingActionRecognizer!.isFaceDetectable {
                self.eatingActionRecognizer!.checkMouseIsMasked(image: image, mask: mask,depth: depth)
            }
            
        }
        
        return
    }
    
    // MARK: - Detect Human Body Pose
    // 手の位置を検出する
//    @available(iOS 14.0, *)
//    func detectHumanPose(depthPixelBuffer: CVPixelBuffer, videoPixelBuffer: CVPixelBuffer, sampleBuffer : CMSampleBuffer){
//
//        //        // Get the CGImage on which to perform requests.
//        //        guard let cgImage = UIImage(named: "bodypose")?.cgImage else { return }
//        //        guard let cgImage = videoPixelBuffer.cgImage else { return }
//        var cgImageWrapper : CGImage?
//        VTCreateCGImageFromCVPixelBuffer(videoPixelBuffer, options: nil, imageOut: &cgImageWrapper)
//        guard let videoImage : CGImage = cgImageWrapper else {return}
//
//
//        //        var depthImageWrapper : CGImage?
//        //        VTCreateCGImageFromCVPixelBuffer(depthPixelBuffer, options: nil, imageOut: &depthImageWrapper)
//        //        guard let depthImage : CGImage = depthImageWrapper else {return}
//
//
//        //        // Create a new image-request handler.
//        let requestHandler = VNImageRequestHandler(cgImage: videoImage)
//
//        //
//        //        // Create a new request to recognize a human body pose.
//        //        ポーズリクエストは簡単に変更できる
//        //        let request = VNDetectHumanBodyPoseRequest(completionHandler: bodyPoseHandler)
//        let request = VNDetectHumanHandPoseRequest()
//        do {
//            // Perform the body pose-detection request.
//            try requestHandler.perform([request])
//        } catch {
//            print("Unable to perform the request: \(error).")
//        }
//
//        //検出後の処理
//        guard let observations =
//                request.results else { return }
//        if !observations.isEmpty {
//            guard let points = try? observations[0].recognizedPoints(forGroupKey: .all) else{return}
//            print("detected")
//            //最も確証度の高い座標を取り出す
//            var max_confidence:Float = 0
//            //            var max_key : VNRecognizedPointKey = .handLandmarkKeyWrist
//            //DEPRECATEDに一時的に対応
//            var max_key : VNRecognizedPointKey = VNRecognizedPointKey.bodyLandmarkKeyRightWrist
//            for(key, value) in points {
//                if value.confidence > max_confidence{
//                    max_key = key
//                    max_confidence = value.confidence
//                }
//            }
//
//            print(max_key.rawValue + " " + String(max_confidence))
//            print(String(points[max_key]?.x ?? -1) + " " + String(points[max_key]?.y ?? -1))
//            //座標をもとに深度を取得
//            guard let max_point = points[max_key] else {return}
//
//            //            let handPoint : CGPoint = CGPoint
//
//            let handPoint : CGPoint = CGPoint(x:(Double(max_point.location.x) * Double(CVPixelBufferGetWidth(depthPixelBuffer))), y: (1 - Double(points[max_key]!.location.y)) * Double(CVPixelBufferGetHeight(depthPixelBuffer)))
//
//            let depthMap = DepthMap(depthPixelBuffer: depthPixelBuffer)
//
//            print(depthMap.getDepth(depthPoint: handPoint))
//
//            let mask = depthMap.createMaskFromDepth(handPoint: handPoint, threshold: 10)
//
//            //            let image = videoImage.masking(mask)
//
//            //            let cvimage = OpenCVWrapper.filteredImage(videoImage)
//            //            let cvimage2 = OpenCVWrapper.binarize(videoImage)?.takeRetainedValue()
//
//            let cvimage3 = OpenCVWrapper.masking(videoImage, mask);
//
//            print(handPoint.debugDescription)
//
//            //マスク画像を使ってフィルター処理
//            //フィルターされた画像を使いセグメンテーション
//            let svimage = UIImage(cgImage: (cvimage3?.takeRetainedValue())!)
//            saveImage(frame: svimage, filename: "test")
//            let i = loadImage(fileName: "test")
//            //            print("test")
//
//        }
//    }
    
    
    // MARK: Recording Features
    //画像を書き出す
//    func saveImage(frame:UIImage,filename:String){
//        var documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let pngData = frame.pngData()
//        let path = documentDirectoryFileURL.appendingPathComponent(filename)
//        do{
//            try pngData?.write(to: path)
//        }catch{
//            print(error)
//        }
//    }
    
    func saveSingleImage(imagePixelBuffer:CVPixelBuffer,filename:String){
        let ci = CIImage(cvPixelBuffer: imagePixelBuffer)
        let context = CIContext()
        let pngData = context.pngRepresentation(of: ci, format: .RGBA16, colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!, options: [:])
        
        let documentDirectoryFileURL = self.singleImageSavingPath
        let path = documentDirectoryFileURL.appendingPathComponent(filename)
        do{
            if(!FileManager.default.fileExists(atPath: documentDirectoryFileURL.path)){
                try FileManager.default.createDirectory(at: documentDirectoryFileURL, withIntermediateDirectories: true, attributes: nil)
            }
            try pngData?.write(to: path)
        }catch{
            print(error)
        }
    }
    
//    @available(*,deprecated)
//    func saveImage2(frame:UIImage,fileName:String){
//        var documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        // DocumentディレクトリのfileURLを取得
//        let path = documentDirectoryFileURL.appendingPathComponent(fileName)
//        documentDirectoryFileURL = path
//
//        let pngImageData = frame.pngData()
//        do{
//            try pngImageData?.write(to: documentDirectoryFileURL)
//            UserDefaults.standard.set(documentDirectoryFileURL, forKey: "userImage")
//        }catch{
//            print(error)
//        }
//
//        UserDefaults.standard.set(documentDirectoryFileURL,forKey: "userImage")
//    }
    
    
    func saveDepth(depthPixelBuffer:CVPixelBuffer,fileName:String){
        
        let documentDirectoryFileURL = self.depthImageSavingPath
        // DocumentディレクトリのfileURLを取得
        let path = documentDirectoryFileURL.appendingPathComponent(fileName)
        
        
        //        CGColorSpace.
        let depthFrame = CIImage(cvPixelBuffer: depthPixelBuffer,options: [CIImageOption.auxiliaryDepth:true,CIImageOption.colorSpace:CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!])
        
        let colorspae = depthFrame.colorSpace!
        let context = CIContext(options: [CIContextOption.workingColorSpace:colorspae,CIContextOption.outputColorSpace:colorspae,CIContextOption.workingFormat: CIFormat.RGBA16,CIContextOption.outputPremultiplied:NSNumber(false)])
        guard let pngImageData = context.pngRepresentation(of: depthFrame, format: .RGBA16, colorSpace: colorspae, options: [:]) else {return}
        
        do{
            if(!FileManager.default.fileExists(atPath: documentDirectoryFileURL.path)){
                try FileManager.default.createDirectory(at: documentDirectoryFileURL, withIntermediateDirectories: true, attributes: nil)
                
            }
            try pngImageData.write(to: path)
            UserDefaults.standard.set(path, forKey: "userImage")
        }catch{
            print(error)
        }
        
        
        UserDefaults.standard.set(documentDirectoryFileURL,forKey: "userImage")
    }
    
//    func loadDepth(fileName : String)->CVPixelBuffer{
//        var documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let path = documentDirectoryFileURL.appendingPathComponent(fileName)
//
//        let ci : CIImage = CIImage(contentsOf: path)!
//        let pb = createPixelBuffer(width: 640, height: 480, pixelFormat: kCVPixelFormatType_DepthFloat16)!
//        let cont : CIContext = CIContext()
//        cont.render(ci, to: pb)
//
//        return pb
//    }
    
    
//    func saveRawData(pixelbuffer:CVPixelBuffer,fileName:String){
//        let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        //        let fileName = "localData.png"
//        // DocumentディレクトリのfileURLを取得
//        let path = documentDirectoryFileURL.appendingPathComponent(fileName)
//        //        documentDirectoryFileURL = path
//
//        CVPixelBufferLockBaseAddress(pixelbuffer, .readOnly)
//        let baseaddr = CVPixelBufferGetBaseAddress(pixelbuffer)
//        let length = CVPixelBufferGetDataSize(pixelbuffer)
//        let width = CVPixelBufferGetWidth(pixelbuffer)
//        let height = CVPixelBufferGetHeight(pixelbuffer)
//        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelbuffer)
//        let data = NSData(bytes: baseaddr, length: length)
//        print(data)
//        try! data.write(to: path, atomically: true)
//        CVPixelBufferUnlockBaseAddress(pixelbuffer, .readOnly)
//
//        //        do{
//        //            AVDepthData.data
//        //            try data.write(to: documentDirectoryFileURL)
//        //            UserDefaults.standard.set(documentDirectoryFileURL, forKey: "userImage")
//        //        }catch{
//        //            print(error)
//        //        }
//
//        UserDefaults.standard.set(path,forKey: "userImage")
//    }
    
    //画像を読み込む
//    func loadImage(fileName:String) -> UIImage{
//        let ud = UserDefaults.standard
//        let data = ud.data(forKey: fileName)!
//        return UIImage(data: data)!
//    }
    
//    @available(*,deprecated)
//    func saveImageAsJPEGFile(to url: URL, image: CIImage) throws {
//        guard let jpegData = CIContext().jpegRepresentation(
//            of: image,
//            colorSpace: image.colorSpace!,
//            options: [:]) else {
//                // JPEGデータ作成失敗
//                print("can't save ciimage!")
//                return
//            }
//
//        try jpegData.write(to: url)
//    }
//    @available(*,deprecated)
//    func saveImageAsJPEGFile2(image: CIImage,fileName:String,depthPixelBuffer:CVPixelBuffer){
//        //        let outputURL: URL? = filePath(forKey: "test")
//        //        let outputURL = NSURL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("/Documents\(NSUUID().uuidString).gif")
//        let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let path = documentDirectoryFileURL.appendingPathComponent(fileName)
//        //        let documentPath = NSHomeDirectory() + "/Documents"
//        //        let outputURL = documentPath + "file.png"
//        guard let cgImageDestination = CGImageDestinationCreateWithURL( path as CFURL, kUTTypePNG, 1, nil) else {
//            return
//        }
//        let context = CIContext(options: nil)
//        let dict: NSDictionary = [
//            kCGImageDestinationLossyCompressionQuality: 1.0,
//            kCGImagePropertyIsFloat: kCFBooleanTrue,
//        ]
//        if let cgImage: CGImage = context.createCGImage(image, from: image.extent) {
//            CGImageDestinationAddImage(cgImageDestination, cgImage, nil)
//            CGImageDestinationFinalize(cgImageDestination)
//            //            let cgi = CGImage.create(pixelBuffer: depthPixelBuffer)!
//            //            let pb2 = cgi.pixelBuffer(width: cgi.width, height: cgi.height, pixelFormatType: kCVPixelFormatType_DepthFloat16, colorSpace: CGColorSpaceCreateDeviceGray(), alphaInfo: .none, orientation: .up)!
//            let pb = cgImage.pixelBuffer(width: cgImage.width, height: cgImage.height, pixelFormatType: kCVPixelFormatType_DepthFloat16, colorSpace: CGColorSpaceCreateDeviceGray(), alphaInfo: .none, orientation: .up)!
//            //            let cg = CGImage.create(pixelBuffer: pb)!
//            let a = getDepth(depthPoint: CGPoint(x: 100,y: 100), depthFrame: depthPixelBuffer)
//            let b = getDepth(depthPoint: CGPoint(x: 100,y: 100), depthFrame: pb)
//            //            let c = getDepth(depthPoint: CGPoint(x: 100,y: 100), depthFrame: pb2)
//
//            print("completed")
//
//        }
//
//
//
//        //        CVPixelBufferCreate(kCFAllocatorDefault, cvpixelbufferget, <#T##height: Int##Int#>, <#T##pixelFormatType: OSType##OSType#>, <#T##pixelBufferAttributes: CFDictionary?##CFDictionary?#>, <#T##pixelBufferOut: UnsafeMutablePointer<CVPixelBuffer?>##UnsafeMutablePointer<CVPixelBuffer?>#>)
//
//
//    }
//    func saveImageAsJPEGFile3(image: CGImage,fileName:String){
//        //        let outputURL: URL? = filePath(forKey: "test")
//        //        let outputURL = NSURL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("/Documents\(NSUUID().uuidString).gif")
//        let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let path = documentDirectoryFileURL.appendingPathComponent(fileName)
//        //        let documentPath = NSHomeDirectory() + "/Documents"
//        //        let outputURL = documentPath + "file.png"
//        guard let cgImageDestination = CGImageDestinationCreateWithURL( path as CFURL, kUTTypePNG, 1, nil) else {
//            return
//        }
//        //        let context = CIContext(options: nil)
//        //                let dict: NSDictionary = [
//        //                    kCGImageDestinationLossyCompressionQuality: 1.0,
//        //                    kCGImagePropertyIsFloat: kCFBooleanTrue,
//        //                ]
//
//        CGImageDestinationAddImage(cgImageDestination, image, nil)
//        CGImageDestinationFinalize(cgImageDestination)
//        print("completed")
//
//    }
    //    func saveDepth(url : URL, pixelbuffer : CVPixelBuffer){
    //        let cgImage = pixelbuffer.
    //
    //    }
    
//    func getDepth(depthPoint:CGPoint,depthFrame:CVPixelBuffer) -> Float{
//
//        assert(kCVPixelFormatType_DepthFloat16 == CVPixelBufferGetPixelFormatType(depthFrame))
//        CVPixelBufferLockBaseAddress(depthFrame, .readOnly)
//        let rowData = CVPixelBufferGetBaseAddress(depthFrame)! + Int(depthPoint.y) * CVPixelBufferGetBytesPerRow(depthFrame)
//        // swift does not have an Float16 data type. Use UInt16 instead, and then translate
//        var f16Pixel = rowData.assumingMemoryBound(to: UInt16.self)[Int(depthPoint.x)]
//        CVPixelBufferUnlockBaseAddress(depthFrame, .readOnly)
//
//        var f32Pixel = Float(0.0)
//        var src = vImage_Buffer(data: &f16Pixel, height: 1, width: 1, rowBytes: 2)
//        var dst = vImage_Buffer(data: &f32Pixel, height: 1, width: 1, rowBytes: 4)
//        vImageConvert_Planar16FtoPlanarF(&src, &dst, 0)
//
//        // Convert the depth frame format to cm
//        let depthString = String(format: "%.2f cm", f32Pixel * 100)
//        print(depthString)
//
//        return f32Pixel
//    }
    
    @IBAction func RecordButtonPushed(_ sender: Any) {
        
        
        //        startRecordingImage(duration: <#T##Float#>)
        
        //保存状態かどうかを確認
        
        
        if(self.ImageModeSwitch.isOn){
            if(self.isRecording){
                stopRecordingImage()
            }else{
                startRecordingImage(duration: 1)
            }
        }
        
        print("record pushed")
        
        if self.videoWriter == nil && self.videoWriterInput == nil
            && self.depthWriter == nil && self.depthWriterInput == nil {
            
            let videoPrefix : String = "video"
            let depthPrefix : String = "depth"
            let classStr : String = ClassField.text ?? ""
            let weightStr : String = WeightField.text ?? ""
            let postfix : String = ".mov"
            
            
            
            //            print(dateFormatter.string(from: dt))
            let videofilePath = NSHomeDirectory() + "/Documents/" + generateFileName(prefix: videoPrefix, cls: classStr, weight: weightStr, postfix: postfix)
            let depthfilePath = NSHomeDirectory() + "/Documents/" + generateFileName(prefix: depthPrefix, cls: classStr, weight: weightStr, postfix: postfix)
            
            let writerAndInput = startRecordingVideo(filePath: videofilePath)
            self.videoWriter = writerAndInput.writer
            self.videoWriterInput = writerAndInput.input
            
            let depthWriterAndInput = startRecordingVideo(filePath: depthfilePath)
            self.depthWriter = depthWriterAndInput.writer
            self.depthWriterInput = depthWriterAndInput.input
            
            
            self.recordButton.setTitle("stop", for: .normal)
        } else {
            let outputURL = stopRecordingVideo()
            self.recordButton.setTitle("record", for: .normal)
            print("record stopped")
            //            playMovieFromUrl(movieUrl: outputURL.videoURL)
            playMovieFromUrl(movieUrl: outputURL.depthURL)
            
            //再生機能
            
            //リリースする
            self.videoWriter = nil
            self.videoWriterInput = nil
            
        }
    }
    
    func playMovieFromUrl(movieUrl: URL?) {
        if let movieUrl = movieUrl {
            let videoPlayer = AVPlayer(url: movieUrl)
            let playerController = AVPlayerViewController()
            playerController.player = videoPlayer
            self.present(playerController, animated: true, completion: {
                videoPlayer.play()
            })
        } else {
            print("cannot play")
        }
    }
    
    func startRecordingImage(duration:Float){
        
        //filenameの処理
        self.depthImageFileName = generateFileName(prefix: "depth", cls: self.ClassField.text!, weight: self.WeightField.text!, postfix: ".png")
        self.singleImageFileName = generateFileName(prefix: "image", cls: self.ClassField.text!, weight: self.WeightField.text!, postfix: ".png")
        self.isRecording = true
        self.isCooltimeSavingImage = true
        self.coolTimeSavingImage = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (time:Timer) in
            print("scheduled function")
            self.isCooltimeSavingImage = false
        })
        
    }
    
    func generateFileName(prefix:String,cls:String,weight:String,postfix:String) -> String{
        let dt = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let timestamp : String = dateFormatter.string(from: dt)
        let depthfileName = prefix + "-" + cls + "-" + weight + "-" + timestamp + postfix
        return depthfileName
    }
    
    
    func handleRecordingImage(depth:CVPixelBuffer,image:CVPixelBuffer){
        guard !self.isCooltimeSavingImage else {return}
        self.depthImageCounter += 1
        let depthFilename = self.depthImageFileName.replacingOccurrences(of: ".png", with: "-"+String(self.depthImageCounter)+".png")
        
        
        let imageFilename = self.singleImageFileName.replacingOccurrences(of: ".png", with: "-"+String(self.depthImageCounter)+".png")
        //画像を保存
        saveDepth(depthPixelBuffer: depth, fileName: depthFilename)
        saveSingleImage(imagePixelBuffer: image, filename: imageFilename)
        print("save file")
        self.isCooltimeSavingImage=true
    }
    
    func stopRecordingImage(){
        
        self.coolTimeSavingImage?.invalidate()
        self.isRecording = false
        self.depthImageCounter = 0
        
    }
    //画像から動画を書き出す
    func startRecordingVideo(filePath:String) -> (writer:AVAssetWriter,input:AVAssetWriterInput){
        let writer = try? AVAssetWriter(outputURL: URL(fileURLWithPath: filePath), fileType: AVFileType.mov)
        // ビデオ入力設定 (h264コーデックを使用・フルHD)
        let videoSettings = [
            AVVideoWidthKey: 640,
            AVVideoHeightKey: 480,
            AVVideoCodecKey: AVVideoCodecType.h264
            //          AVVideoCodecKey: AVVideoCodecType.proRes4444
        ] as [String: Any]
        
        
        let videoOutputSettings = videoSettings
        let videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings)
        videoInput.expectsMediaDataInRealTime = true
        
        //        print(writer?.canAdd(videoInput))
        writer!.add(videoInput)
        
        writer?.startWriting()
        
        var currenttime :CMTime = CMTime.zero
        
        currenttime = self.currentSampleBuffer!.presentationTimeStamp

        writer?.startSession(atSourceTime: currenttime)
        
        
        return (writer!,videoInput)
        
    }
    //    func handleRecordingVideo(){
    //TODO:処理の切り出し
    //    }
    
    func stopRecordingVideo() -> (videoURL:URL,depthURL:URL){
        self.videoWriterInput?.markAsFinished()
        self.depthWriterInput?.markAsFinished()
        let videoUrl : URL = videoWriter!.outputURL
        let depthUrl:URL = depthWriter!.outputURL
        self.videoWriter?.finishWriting {
            self.videoWriter = nil
            self.videoWriterInput = nil
        }
        self.depthWriter?.finishWriting {
            self.depthWriter = nil
            self.depthWriterInput = nil
        }
        return (videoUrl,depthUrl)
    }
    
    // MARK: - Video + Depth Frame Processing
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer,
                                didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        
        if !renderingEnabled {
            return
        }
        
        // Read all outputs
        guard renderingEnabled,
              let syncedDepthData: AVCaptureSynchronizedDepthData =
                synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData,
              let syncedVideoData: AVCaptureSynchronizedSampleBufferData =
                synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else {
                    // only work on synced pairs
                    return
                }
        
        if syncedDepthData.depthDataWasDropped || syncedVideoData.sampleBufferWasDropped {
            return
        }
        
        let depthData = syncedDepthData.depthData
        let depthPixelBuffer = depthData.depthDataMap
        let sampleBuffer = syncedVideoData.sampleBuffer
        guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                  return
              }
        
//        if JETEnabled {
        if true {
            
            if !videoDepthConverter.isPrepared {
                /*
                 outputRetainedBufferCountHint is the number of pixel buffers we expect to hold on to from the renderer.
                 This value informs the renderer how to size its buffer pool and how many pixel buffers to preallocate. Allow 2 frames of latency
                 to cover the dispatch_async call.
                 */
                var depthFormatDescription: CMFormatDescription?
                CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                             imageBuffer: depthPixelBuffer,
                                                             formatDescriptionOut: &depthFormatDescription)
                videoDepthConverter.prepare(with: depthFormatDescription!, outputRetainedBufferCountHint: 2)
            }
            
            guard let jetPixelBuffer = videoDepthConverter.render(pixelBuffer: depthPixelBuffer) else {
                print("Unable to process depth")
                return
            }
            
            
            //深度保存ハンドラ
            if(self.isRecording){
                handleRecordingImage(depth: depthPixelBuffer, image: videoPixelBuffer)
            }
            
            //state handler
            if !self.isCooltime{
                switch currentState {
                case "segmentation":
                    if(!self.isRecording){
                        _ = handleSegmentation(depthPixelBuffer: depthPixelBuffer, videoPixelBuffer: videoPixelBuffer, sampleBuffer: sampleBuffer)
                    }
                case "estimation":
                    if let mask : MLMultiArray = self.segmentator?.getMask(){
                        handleCalorieEstimation(image: videoPixelBuffer, depth: depthPixelBuffer, mask: mask)
                    }
                case "tracking":
                    if let mask : MLMultiArray = self.segmentator?.getMask(){
                        handleEatingAction(image: videoPixelBuffer,mask: mask, depth: depthPixelBuffer)
                    }
                    break
                default:
                    break
                }
            }
            //画像保存フック
            currentSampleBuffer = sampleBuffer
            if let assetWriterInput = self.videoWriterInput {
                if assetWriterInput.isReadyForMoreMediaData {

                    assetWriterInput.append(sampleBuffer)
                }
            }
            
            if let assetWriterInput = self.depthWriterInput {
                if assetWriterInput.isReadyForMoreMediaData {
                    
                    let sample : Sample = Sample(sampleBuffer: sampleBuffer)
                    let depthSampleBuffer =  sample.generateCMSampleBuffer(from: jetPixelBuffer)
                    assetWriterInput.append(depthSampleBuffer!)
                }
            }
            
            if !videoDepthMixer.isPrepared {
                videoDepthMixer.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
            }
            
            // Mix the video buffer with the last depth data we received
            guard let mixedBuffer = videoDepthMixer.mix(videoPixelBuffer: videoPixelBuffer, depthPixelBuffer: jetPixelBuffer) else {
                print("Unable to combine video and depth")
                return
            }
            
            jetView.pixelBuffer = mixedBuffer
            //            print("test")
            
            updateDepthLabel(depthFrame: depthPixelBuffer, videoFrame: videoPixelBuffer, jetFrame: jetPixelBuffer)
        } else {
            // point cloud
//            if self.autoPanningIndex >= 0 {
//
//                // perform a circle movement
//                let moves = 200
//
//                let factor = 2.0 * .pi / Double(moves)
//
//                let pitch = sin(Double(self.autoPanningIndex) * factor) * 2
//                let yaw = cos(Double(self.autoPanningIndex) * factor) * 2
//                self.autoPanningIndex = (self.autoPanningIndex + 1) % moves
//
//                cloudView?.resetView()
//                cloudView?.pitchAroundCenter(Float(pitch) * 10)
//                cloudView?.yawAroundCenter(Float(yaw) * 10)
//            }
//
//            cloudView?.setDepthFrame(depthData, withTexture: videoPixelBuffer)
        }
    }
    
    //テキストエディタを閉じる
    //    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    //        self.view.endEditing(true)
    //    }
    
    @IBAction func onTextEndEditing(_ sender: UITextField) {
        sender.resignFirstResponder()
    }
    //    func onTextFieldEndEditing(_ textfield:UITextField)->Bool{
    //        textfield.resignFirstResponder()
    //        return true
    //    }
    
    func updateDepthLabel(depthFrame: CVPixelBuffer, videoFrame: CVPixelBuffer, jetFrame: CVPixelBuffer) {
        
        if touchDetected && enableTouchDepth {
            guard let texturePoint = jetView.texturePointForView(point: self.touchCoordinates) else {
                DispatchQueue.main.async {
                    self.touchDepth.text = ""
                }
                return
            }
            
            // scale
            let scale = CGFloat(CVPixelBufferGetWidth(depthFrame)) / CGFloat(CVPixelBufferGetWidth(videoFrame))
            let depthPoint = CGPoint(x: CGFloat(CVPixelBufferGetWidth(depthFrame)) - 1.0 - texturePoint.x * scale, y: texturePoint.y * scale)
            
            assert(kCVPixelFormatType_DepthFloat16 == CVPixelBufferGetPixelFormatType(depthFrame))
            CVPixelBufferLockBaseAddress(depthFrame, .readOnly)
            let rowData = CVPixelBufferGetBaseAddress(depthFrame)! + Int(depthPoint.y) * CVPixelBufferGetBytesPerRow(depthFrame)
            // swift does not have an Float16 data type. Use UInt16 instead, and then translate
            var f16Pixel = rowData.assumingMemoryBound(to: UInt16.self)[Int(depthPoint.x)]
            CVPixelBufferUnlockBaseAddress(depthFrame, .readOnly)
            
            var f32Pixel = Float(0.0)
            var src = vImage_Buffer(data: &f16Pixel, height: 1, width: 1, rowBytes: 2)
            var dst = vImage_Buffer(data: &f32Pixel, height: 1, width: 1, rowBytes: 4)
            vImageConvert_Planar16FtoPlanarF(&src, &dst, 0)
            
            // Convert the depth frame format to cm
            let depthString = String(format: "%.2f cm", f32Pixel * 100)
            
            //jet pixel
            CVPixelBufferLockBaseAddress(jetFrame, .readOnly)
            let rowJet = CVPixelBufferGetBaseAddress(jetFrame)! + Int(depthPoint.y) * CVPixelBufferGetBytesPerRow(jetFrame)
            let buffer = rowJet.assumingMemoryBound(to: UInt32.self)[Int(depthPoint.x)]
            // 上位バイトから1バイトづつARGBの順に訳せる
            let bitesString = String(buffer,radix: 16)
            let r = (0x00FF0000 & buffer) >> 16
            let g = (0x0000FF00 & buffer) >> 8
            let b = (0x000000FF & buffer)
            
            //            print(b)
            CVPixelBufferUnlockBaseAddress(jetFrame, .readOnly)
            
            
            //            var cgImageWrapper : CGImage?
            //            VTCreateCGImageFromCVPixelBuffer(jetFrame, options: nil, imageOut: &cgImageWrapper)
            //            guard let depthImage : CGImage = cgImageWrapper else {return}
            
            
            // Update the label
            DispatchQueue.main.async {
                self.touchDepth.textColor = UIColor.white
                self.touchDepth.text = depthString
                self.touchDepth.sizeToFit()
            }
        } else {
            DispatchQueue.main.async {
                self.touchDepth.text = ""
            }
        }
    }
    
}

extension AVCaptureVideoOrientation {
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }
}

extension PreviewMetalView.Rotation {
    
    init?(with interfaceOrientation: UIInterfaceOrientation, videoOrientation: AVCaptureVideoOrientation, cameraPosition: AVCaptureDevice.Position) {
        /*
         Calculate the rotation between the videoOrientation and the interfaceOrientation.
         The direction of the rotation depends upon the camera position.
         */
        switch videoOrientation {
            
        case .portrait:
            switch interfaceOrientation {
            case .landscapeRight:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
                
            case .landscapeLeft:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
                
            case .portrait:
                self = .rotate0Degrees
                
            case .portraitUpsideDown:
                self = .rotate180Degrees
                
            default: return nil
            }
            
        case .portraitUpsideDown:
            switch interfaceOrientation {
            case .landscapeRight:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
                
            case .landscapeLeft:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
                
            case .portrait:
                self = .rotate180Degrees
                
            case .portraitUpsideDown:
                self = .rotate0Degrees
                
            default: return nil
            }
            
        case .landscapeRight:
            switch interfaceOrientation {
            case .landscapeRight:
                self = .rotate0Degrees
                
            case .landscapeLeft:
                self = .rotate180Degrees
                
            case .portrait:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
                
            case .portraitUpsideDown:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
                
            default: return nil
            }
            
        case .landscapeLeft:
            switch interfaceOrientation {
            case .landscapeLeft:
                self = .rotate0Degrees
                
            case .landscapeRight:
                self = .rotate180Degrees
                
            case .portrait:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
                
            case .portraitUpsideDown:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
                
            default: return nil
            }
        @unknown default:
            fatalError("Unknown orientation. Can't continue.")
        }
    }
    
    
}

//extension CMSampleBuffer {
//    static func make(from pixelBuffer: CVPixelBuffer, formatDescription: CMFormatDescription, timingInfo: inout CMSampleTimingInfo) -> CMSampleBuffer? {
//        var sampleBuffer: CMSampleBuffer?
//        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil,
//                                           refcon: nil, formatDescription: formatDescription, sampleTiming: &timingInfo, sampleBufferOut: &sampleBuffer)
//        return sampleBuffer
//    }
//}
//extension CMFormatDescription {
//    static func make(from pixelBuffer: CVPixelBuffer) -> CMFormatDescription? {
//        var formatDescription: CMFormatDescription?
//        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
//        return formatDescription
//    }
//}
