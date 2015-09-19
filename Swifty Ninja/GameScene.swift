//
//  GameScene.swift
//  Swifty Ninja
//
//  Created by Yohannes Wijaya on 9/19/15.
//  Copyright (c) 2015 Yohannes Wijaya. All rights reserved.
//

import SpriteKit

class GameScene: SKScene {
    
    // MARK: - Stored Properties
    
    var gameScore: SKLabelNode!

    var livesImages = [SKSpriteNode]()

    var remainingLives = 3
    
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    var activeSlicePoints = [CGPoint]()
    
    var swooshSoundActive = false
    
    // MARK: - Property Observers
    
    var score: Int = 0 {
        didSet {
            self.gameScore.text = "Score: \(score)"
        }
    }
    
    // MARK: - Methods Override
    
    override func didMoveToView(view: SKView) {
        let backgroundSpriteNode = SKSpriteNode(imageNamed: "sliceBackground")
        backgroundSpriteNode.position = CGPointMake(512, 384)
        backgroundSpriteNode.blendMode = SKBlendMode.Replace
        self.addChild(backgroundSpriteNode)
        
        self.physicsWorld.gravity = CGVectorMake(0, -6)
        self.physicsWorld.speed = 0.85

        self.createScore()
        self.createLives()
        self.createSlices()
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesBegan(touches, withEvent: event)
        
        self.activeSlicePoints.removeAll(keepCapacity: true)
        
        let touch = touches.first!
        let location = touch.locationInNode(self)
        self.activeSlicePoints.append(location)
        
        self.redrawActiveSlice()
        
        self.activeSliceBG.removeAllActions()
        self.activeSliceFG.removeAllActions()
        
        self.activeSliceBG.alpha = 1.0
        self.activeSliceFG.alpha = 1.0
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        self.touchesEnded(touches!, withEvent: event!)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.activeSliceBG.runAction(SKAction.fadeOutWithDuration(0.25))
        self.activeSliceFG.runAction(SKAction.fadeOutWithDuration(0.25))
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touch = touches.first!
        let location = touch.locationInNode(self)
        
        self.activeSlicePoints.append(location)
        self.redrawActiveSlice()
        
        guard self.swooshSoundActive else {
            self.playSwooshSound()
            return
        }
    }
   
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
    }
    
    // MARK: - Local Methods
    
    func createScore() {
        self.gameScore = SKLabelNode(fontNamed: "Chalkduster")
        self.gameScore.text = "Score: 0"
        self.gameScore.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.Left
        self.gameScore.fontSize = 48.0
        self.gameScore.position = CGPointMake(8.0, 8.0)
        self.addChild(self.gameScore)
    }
    
    func createLives() {
        for i in 0 ..< 3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPointMake(CGFloat(834 + (i * 70)), 720.0)
            self.addChild(spriteNode)
            self.livesImages.append(spriteNode)
        }
    }
    
    func createSlices() {
        self.activeSliceBG = SKShapeNode()
        self.activeSliceBG.zPosition = 2
        self.activeSliceBG.strokeColor = UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0)
        self.activeSliceBG.lineWidth = 9.0
        
        self.activeSliceFG = SKShapeNode()
        self.activeSliceFG.zPosition = 2
        self.activeSliceFG.strokeColor = UIColor.whiteColor()
        self.activeSliceFG.lineWidth = 5.0
        
        self.addChild(self.activeSliceBG)
        self.addChild(self.activeSliceFG)
    }
    
    func playSwooshSound() {
        self.swooshSoundActive = true
        
        let randomNumber = RandomInt(1, max: 3)
        let soundName = "swoosh\(randomNumber).caf"
        let swooshSoundAction = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        
        self.runAction(swooshSoundAction) { [unowned self] () -> Void in
            self.swooshSoundActive = false
        }
        
        
    }
    
    func redrawActiveSlice() {
        guard activeSlicePoints.count >= 2 else {
            self.activeSliceBG.path = nil
            self.activeSliceFG.path = nil
            return
        }
        
        while self.activeSlicePoints.count > 12 { self.activeSlicePoints.removeAtIndex(0) }
        
        let bezierPath = UIBezierPath()
        bezierPath.moveToPoint(self.activeSlicePoints.first! as CGPoint)
        
        for index in 1 ..< self.activeSlicePoints.count {
            bezierPath.addLineToPoint(self.activeSlicePoints[index])
        }
        
        self.activeSliceBG.path = bezierPath.CGPath
        self.activeSliceFG.path = bezierPath.CGPath
    }
}
