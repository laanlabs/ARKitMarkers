//
//  MetalScene.swift
//  ARMeasure
//
//  Created by cc on 8/5/17.
//  Copyright © 2017 Laan Labs. All rights reserved.
//

import Foundation

protocol MetalBasedTool {
    
    func setMetalScene( _ scene : MetalScene )
    //func setMetalLayer( _ layer : CAMetalLayer )
    //func metalUpdate()
    
}

protocol MetalNode {
    
    func setupPipeline(device : MTLDevice, pixelFormat: MTLPixelFormat)
    
    // vertBrush.render(commandQueue, encoder, parentModelViewMatrix: modelViewMat, projectionMatrix: projMat)
    func render(commandQueue: MTLCommandQueue,
                renderEncoder: MTLRenderCommandEncoder,
                parentModelViewMatrix: float4x4,
                projectionMatrix: float4x4)
    
    func isPipelineSetup() -> Bool
    
}

class MetalScene {
    
    var nodes : [MetalNode] = []
    //var nodeSet : Set<MetalNode> = []
    var device: MTLDevice
    var metalLayer: CAMetalLayer
    
    init(device : MTLDevice, metalLayer : CAMetalLayer) {
        
        self.device = device
        self.metalLayer = metalLayer
        
    }
    // TODO: make this work
    func removeNode( _ node : MetalNode ) {
        assert(false, "Implement this")
        
        /*let anyNode = node as? AnyObject
        
        let idx = self.nodes.index(where: { n -> Bool in
            return (anyNode) === (n as AnyObject)
        })
        
        nodes.remove(at: idx)
        */
        
    }
    
    func addNode(_ node : MetalNode ) {
        
        self.nodes.append(node)
        
        
        
    }
    
    func render(commandQueue: MTLCommandQueue,
                renderEncoder: MTLRenderCommandEncoder,
                parentModelViewMatrix: float4x4,
                projectionMatrix: float4x4) {
        
        for node in self.nodes {
            
            if ( !node.isPipelineSetup() ) {
                node.setupPipeline(device: self.device, pixelFormat: self.metalLayer.pixelFormat )
            }
            
            node.render(commandQueue: commandQueue,
                        renderEncoder: renderEncoder,
                        parentModelViewMatrix: parentModelViewMatrix,
                        projectionMatrix: projectionMatrix )
        }
    }
    
    
}

// Dumping this here for now
extension MTLTexture {
    
    /*
     func bytes() -> UnsafeMutableRawPointer {
     let width = self.width
     let height   = self.height
     let rowBytes = self.width * 4
     let p = malloc(width * height * 4)
     
     self.getBytes(p!, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
     
     return p!
     }
     
     func toImage() -> CGImage? {
     let p = bytes()
     
     let pColorSpace = CGColorSpaceCreateDeviceRGB()
     
     let rawBitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
     let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: rawBitmapInfo)
     
     let selftureSize = self.width * self.height * 4
     let rowBytes = self.width * 4
     let provider = CGDataProviderCreateWithData(nil, p, selftureSize, nil)
     let cgImageRef = CGImageCreate(self.width, self.height, 8, 32, rowBytes, pColorSpace, bitmapInfo, provider, nil, true, CGColorRenderingIntent.RenderingIntentDefault)!
     
     return cgImageRef
     }
     */
    
    private func freeImageData(info: UnsafeMutableRawPointer, data: UnsafeRawPointer, size: Int) {
        free(UnsafeMutableRawPointer(mutating: data))
    }
    
    func getImage() -> UIImage {
        
        var data = Data.init(count: self.width * self.height * 4 )
        
        self.getBytes(&data, bytesPerRow: self.width * 4, from: MTLRegionMake2D(0, 0, self.width, self.height), mipmapLevel: 0)
        
        let pColorSpace = CGColorSpaceCreateDeviceRGB()
        let rawBitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: rawBitmapInfo)
        let selftureSize = self.width * self.height * 4
        let rowBytes = self.width * 4
        let provider = CGDataProvider(dataInfo: nil, data: &data, size: selftureSize, releaseData: freeImageData as! CGDataProviderReleaseDataCallback)
        //let provider = CGDataProviderCreat
        let cgImageRef = CGImage(width: self.width, height: self.height, bitsPerComponent: 8, bitsPerPixel: 32,
                                 bytesPerRow: rowBytes, space: pColorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)!
        //CGDataProvider.init(data: CFData( )
        let image = UIImage(cgImage: cgImageRef)
        
        return image
        
        
        /*
         NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
         CGColorSpaceRef colorSpace;
         
         if (cvMat.elemSize() == 1) {
         colorSpace = CGColorSpaceCreateDeviceGray();
         } else {
         colorSpace = CGColorSpaceCreateDeviceRGB();
         }
         
         CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
         
         // Creating CGImage from cv::Mat
         CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
         cvMat.rows,                                 //height
         8,                                          //bits per component
         8 * cvMat.elemSize(),                       //bits per pixel
         cvMat.step[0],                            //bytesPerRow
         colorSpace,                                 //colorspace
         kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
         provider,                                   //CGDataProviderRef
         NULL,                                       //decode
         false,                                      //should interpolate
         kCGRenderingIntentDefault                   //intent
         );
         
         
         // Getting UIImage from CGImage
         UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
         CGImageRelease(imageRef);
         CGDataProviderRelease(provider);
         CGColorSpaceRelease(colorSpace);
         
         return finalImage;
         */
        
    }
    
}
