//
//  VertBrush.swift
//  ARBrush
//


import Foundation
import SceneKit



class VertBrush : MetalNode {
    
    // MARK: Metal
    let vertsPerPoint = 8
    let maxPoints : Int

    
    var vertexBuffer: MTLBuffer! = nil
    var indexBuffer: MTLBuffer! = nil
    
    var pipelineState: MTLRenderPipelineState! = nil
    var hasSetupPipeline = false
    
    var mNoDepthTest : MTLDepthStencilState! = nil
    
    var previousSplitLine = false
    
    var bufferProvider: BufferProvider! = nil
    
    
    var vertices = [Vertex]()
    var points = [SCNVector3]()
    var colors = [SCNVector3]()
    var indices = Array<UInt32>()
    
    var lastVertUpdateIdx = 0
    var lastIndexUpdateIdx = 0
    
    var prevPerpVec = SCNVector3Zero
    
    
    var light = Light(color: (1.0,1.0,1.0), ambientIntensity: 0.1,
                      direction: (0.0, 0.0, 1.0), diffuseIntensity: 0.8,
                      shininess: 10, specularIntensity: 2, time: 0.0)
    
    
    init(maxPoints : Int = 10000) {
        self.maxPoints = maxPoints
    }

    fileprivate typealias RGBA = (CGFloat, CGFloat, CGFloat, CGFloat)

    func addPoint( _ point : SCNVector3 , radius : Float = 0.01,
                   splitLine : Bool = false ,
                   color : UIColor , perpVec : SCNVector3! = nil ) {
        
        if ( points.count >= maxPoints ) {
            print("Max points reached")
            return
        }
        
        points.append(point)
        
        var (r,b,g,a): RGBA = (CGFloat(1.0), CGFloat(1.0), CGFloat(1.0), CGFloat(1.0))
        
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        colors.append(SCNVector3(r,g,b))
        
        if ( points.count == 1  ) {
            return
        }
        
        if ( splitLine ) {
            previousSplitLine = true
            return
        }
        
        
        //let green = 0.5 + 0.5*sin( 0.1 * Float(points.count) )
        
        func toVert(_ pp:SCNVector3, _ nn:SCNVector3 , _ col : SCNVector3) -> Vertex {
            return Vertex(x: pp.x, y: pp.y, z: pp.z,
                          r: col.x, g: col.y, b: col.z, a: 1.0,
                          s: 0, t: 0,
                          nX: nn.x, nY: nn.y, nZ: nn.z)
        }
        
        let pidx = points.count - 1
        
        let p1: SCNVector3 = points[pidx]
        let p2: SCNVector3 = points[pidx-1]
        
        let c1: SCNVector3 = colors[pidx]
        let c2: SCNVector3 = colors[pidx-1]
        
        let v1: SCNVector3 = p1 - p2
        
        var v2: SCNVector3 = SCNVector3Zero
        
        if ( SCNVector3EqualToVector3(prevPerpVec, SCNVector3Zero) ) {
            v2 = v1.cross(vector: SCNVector3(1.0, 1.0, 1.0)).normalized() * radius
        } else {
            v2 = SCNVector3ProjectPlane(vector: prevPerpVec, planeNormal: v1.normalized() ).normalized() * radius
        }
        
        prevPerpVec = v2
        
        if perpVec != nil {
            v2 = perpVec * radius
        }
        
        // add p2 verts only if this is 2nd point
        if ( points.count == 2 || previousSplitLine ) {
            previousSplitLine = false
            
            for i in 0..<vertsPerPoint {
                
                let angle: Float = (Float(i) / Float(vertsPerPoint)) * Float.pi * 2.0
                
                //let scale = 0.25 * cos(angle) + 0.75
                let scale : Float = 1.0 // 2*cos(angle) + 2.1
                
                let v3 : SCNVector3 = SCNVector3Rotate(vector:v2, around:v1, radians:angle) * scale
                
                let cnew = SCNVector3(c2.x, c2.y * (angle / Float.pi * 2.0), c2.z)
                
                vertices.append(toVert(p2 + v3, v3.normalized(), cnew))
                //vertices.append(toVert(p2 + v3, v3.normalized(), c2))
                
            }
        }
        
        let idx_start : UInt32 = UInt32(vertices.count)
        //print("------")
        // add current point's verts
        for i in 0..<vertsPerPoint {
            let angle: Float = (Float(i) / Float(vertsPerPoint)) * Float.pi * 2.0
            //let scale = 0.25 * cos(angle) + 0.75
            let scale : Float = 1.0 // 2*cos(angle) + 2.1
            
            //print(" scale: %4.2f  angle: %4.2f ".format( scale, angle) )
            
            let v3: SCNVector3 = SCNVector3Rotate(vector:v2, around:v1, radians:angle) * scale
            //let cnew = SCNVector3(1.0, angle / Float.pi * 2.0, 0.1)
            let cnew = SCNVector3(c1.x, c1.y * (angle / Float.pi * 2.0), c1.z)
            vertices.append(toVert(p1 + v3, v3.normalized(), cnew))
            //vertices.append(toVert(p1 + v3, v3.normalized(), c1))
        }
        
        // add triangles
        
        let N : UInt32 = UInt32(vertsPerPoint)
        
        for i in 0..<vertsPerPoint {
            
            let idx : UInt32 = idx_start + UInt32(i)
            
            if ( i == vertsPerPoint-1 ) {
                
                indices.append( idx )
                indices.append( idx - N )
                indices.append( idx_start - N)
                
                indices.append( idx )
                indices.append( idx_start - N )
                indices.append( idx_start )
                
            } else {
                
                indices.append( idx )
                indices.append( idx - N )
                indices.append( idx - N + 1 )
                
                indices.append( idx )
                indices.append( idx - N + 1 )
                indices.append( idx + 1 )
                
            }
        }
        
        
    }
    
    func updateBuffers() {
        if ( vertices.count == 0 ) {return}
        objc_sync_enter(self)
        updateIndexBuffer()
        updateVertexBuffer()
        objc_sync_exit(self)
    }
    
    
    func updateVertexBuffer() {
        
        let count = vertices.count
        let num = count - lastVertUpdateIdx
        let bufferPointer = vertexBuffer.contents()
        let dataSize = num * MemoryLayout<Vertex>.size
        let offset = lastVertUpdateIdx * MemoryLayout<Vertex>.size
        
        memcpy(bufferPointer + offset, &vertices+lastVertUpdateIdx, dataSize)
        lastVertUpdateIdx = count
        
    }
    
    func updateIndexBuffer() {
        
        let count = indices.count
        let num = count - lastIndexUpdateIdx
        let bufferPointer = indexBuffer.contents()
        let dataSize = num * 4
        let offset = 4 * lastIndexUpdateIdx
        memcpy(bufferPointer + offset, &indices+lastIndexUpdateIdx, dataSize)
        lastIndexUpdateIdx = count
        
    }
 
    
    
    func clear() {
        objc_sync_enter(self)
        vertices.removeAll()
        indices.removeAll()
        points.removeAll()
        colors.removeAll() // TODO: remove colors array
        lastIndexUpdateIdx = 0
        lastVertUpdateIdx = 0
        objc_sync_exit(self)
    }
    
    // Metal
    
    func render(commandQueue: MTLCommandQueue,
                renderEncoder: MTLRenderCommandEncoder,
                parentModelViewMatrix: float4x4,
                projectionMatrix: float4x4) {
        
        
        if ( indices.count == 0 ) {return}
        
        objc_sync_enter(self)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        light.time = light.time + 0.1
        
        let uniformBuffer = bufferProvider.nextUniformsBuffer(projectionMatrix,
                                                              modelViewMatrix: parentModelViewMatrix,
                                                              light: light)
        
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        
        //renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        renderEncoder.setTriangleFillMode(.fill)
        
        renderEncoder.setDepthStencilState(mNoDepthTest!)
        
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: indices.count,
                                            indexType: MTLIndexType.uint32,
                                            indexBuffer: indexBuffer,
                                            indexBufferOffset: 0)
        
//        currentBufferIdx += 1
//
//        if ( currentBufferIdx == numBuffers ) {
//            currentBufferIdx = 0
//        }
        
        objc_sync_exit(self)
        
        //self.bufferProvider.avaliableResourcesSemaphore.signal()
        
        
    }
    
    func isPipelineSetup() -> Bool {
        return hasSetupPipeline
    }
    
    
    func setupPipeline(device : MTLDevice, pixelFormat : MTLPixelFormat ) {
        
        let defaultLibrary = device.makeDefaultLibrary()
        let fragmentProgram = defaultLibrary!.makeFunction(name: "airbrush_fragment")
        let vertexProgram = defaultLibrary!.makeFunction(name: "brush_vertex")
        
        
        let depthStencilDesc = MTLDepthStencilDescriptor()
        //depthStencilDesc.depthCompareFunction = .
        depthStencilDesc.isDepthWriteEnabled = true
        depthStencilDesc.depthCompareFunction = .lessEqual
        mNoDepthTest = device.makeDepthStencilState(descriptor: depthStencilDesc)
        
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipelineStateDescriptor.depthAttachmentPixelFormat = MTLPixelFormat.depth32Float
        
        
        
        //pipelineStateDescriptor.colorAttachments[0].
        pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperation.add;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperation.add;
        
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactor.one;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactor.sourceAlpha;
        
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactor.oneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactor.oneMinusSourceAlpha;
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        
        let vertDataSize = vertsPerPoint * maxPoints * MemoryLayout<Vertex>.size
        let indexDataSize = 3 * vertsPerPoint * maxPoints * MemoryLayout<UInt32>.size
        
//        for _ in 0..<numBuffers {
//            vertexBuffers.append( device.makeBuffer(length: vertDataSize, options: [])! )
//            indexBuffers.append( device.makeBuffer(length: indexDataSize, options: [])! )
//        }
        
        vertexBuffer = device.makeBuffer(length: vertDataSize, options: [])
        indexBuffer = device.makeBuffer(length: indexDataSize, options: [])
        
        self.bufferProvider = BufferProvider(device: device, inflightBuffersCount: 3)
        
        hasSetupPipeline = true
        
    }
    
    
}
