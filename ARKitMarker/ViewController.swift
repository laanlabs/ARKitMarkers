//
//  ViewController.swift
//  ARKitMarker
//
//  Created by cc on 2/20/18.
//  Copyright © 2018 Laan Labs. All rights reserved.
//

/*

 Quick hack project to get Aruco markers into ARKit.
 
 Press and hold on the screen to draw
 
 You must set the marker length below for each marker you print out
 
 You can generate and print markers from here:
 https://terpconnect.umd.edu/~jwelsh12/enes100/markergen.html
 
 Currently all marker IDs will be drawn.. you can manually set which IDs to accept
 in OpenCVWrapper.mm in findMarkers.
 
 This project uses a build of opencv with aruco module enabled.
 To rebuild it, just google for 'build opencv with modules'
 basically just copy the aruco folder into the modules folder and rebuild the framework
 
*/

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNNodeRendererDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var drawButton : UIButton! = nil
    
    
    
    var lastDistance : Float! = nil
    var lastPos : SCNVector3! = nil
    var lastFoundPos : SCNVector3! = nil
    var lastFoundxDir : SCNVector3! = nil
    var lastFoundRotMat : SCNMatrix4! = nil
    
    var ballNode : SCNNode! = nil
    
    var vertBrush : VertBrush! = nil
    
    var metalScene : MetalScene! = nil
    var brushColor : UIColor = UIColor.red
    
    var brushRadius : Float = 0.002
    
    let minPointAddDist : Float = 0.0002
    var splitLine = false
    var useVariableBrushSize = false
    
    var brushSizes : [Float] = [0.003, 0.008, 0.016]
    var metalDrawNode : SCNNode! = nil
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/world.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        
        self.setupBrush()
        
        
        self.ballNode = getBall(color: UIColor.green.withAlphaComponent(0.8), radius: 0.005)
        self.sceneView.scene.rootNode.addChildNode(ballNode)
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    
    // MARK: - Metal setup
    func setupBrush() {
        
        
        
        assert(sceneView.renderingAPI == SCNRenderingAPI.metal)
        
        
        let metalLayer = self.sceneView.layer as! CAMetalLayer
        let device = self.sceneView.device!
        self.metalScene = MetalScene(device: device, metalLayer: metalLayer)
        
        
    
        vertBrush = VertBrush()
        self.metalScene.addNode(vertBrush)
    
        
        
        metalDrawNode = SCNNode(geometry:SCNPlane(width: 0.01, height: 0.01))
        self.sceneView.scene.rootNode.addChildNode(metalDrawNode)
        metalDrawNode.rendererDelegate = self
        metalDrawNode.constraints = [SCNBillboardConstraint()]
        //metalDrawNode.renderOnTop()
        
        
        
        self.brushRadius = brushSizes[0]
        
        
        
        drawButton = UIButton()
        drawButton.frame = .init(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        drawButton.addTarget(self, action: #selector(buttonDown), for: .touchDown)
        drawButton.addTarget(self, action: #selector(buttonUp), for: .touchUpInside)
        
        
        self.view.addSubview(drawButton)
        
        
    }
        
    
    
    @objc func buttonDown() {
        splitLine = true
        isDrawing = true
    }
    
    @objc func buttonUp() {
        isDrawing = false
    }
    
    
    
    // MARK: - Marker / Drawing stuff
    
    
    
    func updateMarker() {
        
        
        guard let frame = self.sceneView.session.currentFrame else { return }
        
        let pixelBuffer = frame.capturedImage
        
        
        
        
        //matrix_float3x3
        let fx = frame.camera.intrinsics.columns.0.x
        let fy = frame.camera.intrinsics.columns.1.y
        //let s = frame.camera.intrinsics.columns.1.x
        
        let ox = frame.camera.intrinsics.columns.2.x
        let oy = frame.camera.intrinsics.columns.2.y
        
        guard let camera = self.sceneView.pointOfView else { return }
        
        let markerLengthMM : Float32 = 100.0
        
        let markerLength : Float32 = markerLengthMM / 1000.0
        
        let imageDownsample : Float32 = 2.5 // adjust to your speed / quality tradeoff
        
        //let d1 = Date()
        let result = OpenCVWrapper.findMarkers(pixelBuffer, fx: fx, fy: fy, ox: ox, oy: oy,
                                               markerLengthMeters: markerLength,
                                               imageDownsample: imageDownsample)
        //let dur = d1.millisecondsAgo

        
        if result.found {
            
            let dist = -result.tvec.z
            
            if lastDistance == nil {
                lastDistance = dist
            }
            
            lastDistance = lastDistance - ( lastDistance - dist ) * 0.1
            
            let posInCam = SCNVector3(-result.tvec.y, -result.tvec.x, lastDistance )
            
            let camMat = SCNMatrix4ToGLKMatrix4(camera.worldTransform)
            
            let worldPos = SCNVector3FromGLKVector3(GLKMatrix4MultiplyVector3WithTranslation(camMat, SCNVector3ToGLKVector3(posInCam)))
            
            //let dist = (self.pointer.cameraPosition - worldPos).length()
            
            let rotMat = result.rotMat
            
            var xDir = rotMat.xAxis
            xDir = SCNVector3( xDir.y, xDir.x , xDir.z )
            let xWorldDir = SCNVector3FromGLKVector3(GLKMatrix4MultiplyVector3(camMat, SCNVector3ToGLKVector3(xDir)))
            let worldRot = SCNMatrix4Mult(rotMat, camera.worldTransform)
            
            ballNode.position = worldPos
            
            if lastPos == nil {
                lastPos = worldPos
            }
            
            lastFoundPos = worldPos
            lastFoundRotMat = worldRot
            
            lastFoundxDir = xWorldDir
            
            
        }
        
        
        if lastFoundPos != nil {
            
            lastPos = lastPos! - (lastPos - lastFoundPos) * 0.35

            if isDrawing {
                self.addBrushPoint( lastPos )
            }

            /*
             node.transform = SCNMatrix4GetAxesTransform(newX: lastFoundRotMat.xAxis,
             newY: lastFoundRotMat.yAxis,
             newZ: lastFoundRotMat.zAxis,
             position: lastPos)
             */
            
        }
        
        
        
        
    }
    
    
    // MARK: - Drawing
    
    private var lineRadius : Float = 0.001
    private var isDrawing = false
    
    func addBrushPoint( _ pos : SCNVector3 ) {
        
        if ( vertBrush.points.count == 0 || (vertBrush.points.last! - pos).length() > minPointAddDist ) {
            
            if ( splitLine || vertBrush.points.count < 2 ) {
                lineRadius = self.brushRadius
            } else {
                if useVariableBrushSize {
                    let i = vertBrush.points.count-1
                    let p1 = vertBrush.points[i]
                    let p2 = vertBrush.points[i-1]
                    let radius = self.brushRadius + min(0.015, 0.005 * pow( ( p2-p1 ).length() / 0.005, 2))
                    lineRadius = lineRadius - (lineRadius - radius)*0.075
                } else {
                    lineRadius = self.brushRadius
                }
            }
            
            
            vertBrush.addPoint(pos,
                               radius: lineRadius,
                               splitLine:splitLine,
                               color : self.brushColor,
                               perpVec: lastFoundRotMat.xAxis.normalized() )
            
            if ( splitLine ) { splitLine = false }
            
            vertBrush.updateBuffers()
            
        }
        
        
        
    }
    
    func getBall(color : UIColor, radius: CGFloat = 0.01) -> SCNNode {
        
        //let bw : CGFloat = 0.01
        let boxGeometry = SCNSphere(radius:radius)
        let boxNode = SCNNode(geometry: boxGeometry)
        
        //boxNode.worldPosition = initialPoint!
        boxGeometry.firstMaterial?.diffuse.contents = color
        boxGeometry.firstMaterial?.lightingModel = .constant
        
        return boxNode
        
    }

    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        self.updateMarker()
    }
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    
    var renderCount = 0
    
    // MARK: SCNNodeRendererDelegate
    func renderNode(_ node: SCNNode, renderer: SCNRenderer, arguments: [String : Any]) {
        
        if let commandQueue = renderer.commandQueue {
            if let encoder = renderer.currentRenderCommandEncoder {
                
                let projMat = float4x4.init((self.sceneView.pointOfView?.camera?.projectionTransform)!)
                let modelViewMat = float4x4.init((self.sceneView.pointOfView?.worldTransform)!).inverse
                
                self.metalScene.render(commandQueue: commandQueue,
                                       renderEncoder: encoder,
                                       parentModelViewMatrix: modelViewMat,
                                       projectionMatrix: projMat)
                
            }
        }
        
    }
    
    
}
