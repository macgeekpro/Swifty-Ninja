//
//  GameScene.swift
//  Swifty Ninja
//
//  Created by Yohannes Wijaya on 9/19/15.
//  Copyright (c) 2015 Yohannes Wijaya. All rights reserved.
//

import SpriteKit
import AVFoundation

enum SequenceType: Int {
    case OneNoBomb, One, TwoWithOneBomb, Two, Three, Four, Chain, FastChain
}

enum ForceBomb {
    case Never
    case Always
    case Default
}

class GameScene: SKScene {
    
    // MARK: - Stored Properties
    
    var gameScore: SKLabelNode!

    var livesImages = [SKSpriteNode]()
    var activeEnemies = [SKSpriteNode]()

    var remainingLives = 3
    
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    var activeSlicePoints = [CGPoint]()
    
    var swooshSoundActive = false
    var bombSoundEffect: AVAudioPlayer!
    
    var popupTimeBetweenSpawn = 0.9
    var sequenceOfEnemiesToCreate: [SequenceType]!
    var sequencePositionCurrently = 0
    var delayToCreateChainedEnemies = 3.0
    var nextSequenceQueued = true
    
    var gameEnded = false
    
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
        
        self.sequenceOfEnemiesToCreate = [SequenceType.OneNoBomb, .OneNoBomb, .TwoWithOneBomb, .TwoWithOneBomb, .Three, .One, .Chain]
        
        for _ in 0 ... 1000 {
            let nextSequence = SequenceType(rawValue: RandomInt(2, max: 7))!
            self.sequenceOfEnemiesToCreate.append(nextSequence)
        }
        
        runAfterDelay(2) { [unowned self] () -> Void in
            self.tossEnemies()
        }
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesBegan(touches, withEvent: event)
        
        // 1. Remove all existing points in the activeSlicePoints array, because we're starting fresh.
        self.activeSlicePoints.removeAll(keepCapacity: true)
        
        // 2. Get the touch location and add it to the activeSlicePoints array.
        if let touch = touches.first {
            let location = touch.locationInNode(self)
            self.activeSlicePoints.append(location)
            
            // 3. Clear the slice shapes.
            self.redrawActiveSlice()
            
            // 4. Remove any action that is currently attached to the slice shapes. This'll be importnat if they're in the middle of a fadeOutWithDuration() action
            self.activeSliceBG.removeAllActions()
            self.activeSliceFG.removeAllActions()
            
            // 5. Set both slice shapes to have an alpha value of 1 so they are fully visible.
            self.activeSliceBG.alpha = 1.0
            self.activeSliceFG.alpha = 1.0
        }
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        self.touchesEnded(touches!, withEvent: event!)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.activeSliceBG.runAction(SKAction.fadeOutWithDuration(0.25))
        self.activeSliceFG.runAction(SKAction.fadeOutWithDuration(0.25))
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if self.gameEnded { return }
        
        let touch = touches.first!
        let location = touch.locationInNode(self)
        
        self.activeSlicePoints.append(location)
        self.redrawActiveSlice()
        
        guard self.swooshSoundActive else {
            self.playSwooshSound()
            return
        }
        
        let nodes = self.nodesAtPoint(location)
        for node in nodes {
            if node.name == "enemy" {
                // destroy penguin
                
//                self.destroyNodes(node: SKNode, incrementScore: Int = 0, soundFile: String,
                
                // 1. Create a particle effect over the penguin.
                let emitterNode = SKEmitterNode(fileNamed: "sliceHitEnemy.sks")!
                emitterNode.position = node.position
                self.addChild(emitterNode)
                
                // 2. Clear its node name so that it can't be swiped repeatedly.
                node.name = ""
                
                // 3. Disable the dynamic of its phyiscs body so that it doesn't carry on falling.
                node.physicsBody!.dynamic = false
                
                // 4. Make the penguin scale out and fade out at the same time.
                let scaleOut = SKAction.scaleTo(0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOutWithDuration(0.2)
                let group  = SKAction.group([scaleOut, fadeOut])
                
                // 5. After making the penguin scale out and fade out, we should remove it from the scene.
                let sequence = SKAction.sequence([group, SKAction.removeFromParent()])
                node.runAction(sequence)
                
                // 6. Add 1 to the player's score (only when penguin is sliced)
                ++self.score
                
                // 7. Remove the enemy from our activeEnemies array.
                let index = self.activeEnemies.indexOf(node as! SKSpriteNode)!
                self.activeEnemies.removeAtIndex(index)
                
                // 8. Play a sound so the player knows they hit the penguin.
                self.runAction(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
                
            }
            else if node.name == "bomb" {
                // destroy bomb
            
                let emitterNode = SKEmitterNode(fileNamed: "sliceHitBomb.sks")!
                emitterNode.position = node.parent!.position
                self.addChild(emitterNode)
                
                node.name = ""
                node.parent!.physicsBody!.dynamic = false
                
                let scaleOut = SKAction.scaleTo(0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOutWithDuration(0.2)
                let group  = SKAction.group([scaleOut, fadeOut])
                
                let sequence = SKAction.sequence([group, SKAction.removeFromParent()])
                node.parent!.runAction(sequence)
        
                let index = self.activeEnemies.indexOf(node as! SKSpriteNode)!
                self.activeEnemies.removeAtIndex(index)
                
                self.runAction(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
                self.endGame(triggeredByBomb: true)
            }
        }
    }
   
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
        
        var bombCount = 0
        
        for spriteNode in self.activeEnemies {
            if spriteNode.name == "bombContainer" {
                ++bombCount
                break
            }
        }
        
        if bombCount == 0 {
            // no bomb, stop the fuse sound!
            if self.bombSoundEffect != nil {
                self.bombSoundEffect.stop()
                self.bombSoundEffect = nil
            }
        }
        
        if self.activeEnemies.count > 0 {
            for spriteNode in self.activeEnemies {
                if spriteNode.position.y < -140 {
                    spriteNode.removeAllActions()
                    
                    if spriteNode.name == "enemy" {
                        spriteNode.name = ""
                        self.subtractLife()
                        
                        spriteNode.removeFromParent()
                        
                        if let index = self.activeEnemies.indexOf(spriteNode) {
                            self.activeEnemies.removeAtIndex(index)
                        }
                        else if spriteNode.name == "bombContainer" {
                            spriteNode.name = ""
                            spriteNode.removeFromParent()
                            
                            if let index = self.activeEnemies.indexOf(spriteNode) {
                                self.activeEnemies.removeAtIndex(index)
                            }
                        }
                    }
                }
            }
        }
        else {
            if !nextSequenceQueued {
                runAfterDelay(self.popupTimeBetweenSpawn, block: { [unowned self] () -> Void in
                    self.tossEnemies()
                })
            self.nextSequenceQueued = true
            }
        }
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
    
    func createEnemy(forceBomb: ForceBomb = .Default) {
        var enemy: SKSpriteNode!
        
        var enemyType = RandomInt(0, max: 6)
        
        if forceBomb == ForceBomb.Never {
            enemyType = 1
        }
        else if forceBomb == ForceBomb.Always {
            enemyType = 0
        }
        
        if enemyType == 0 {
            // 1. Create a new SKSpriteNode that will hold the fuse and the bomb image as children, setting its Z position to be 1.
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            
            // 2. Create the bomb image, name it "bomb", and add it to the container.
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage)
            
            // 3. If the bomb fuse sound effect is playing, stop it and destroy it.
            if self.bombSoundEffect != nil {
                self.bombSoundEffect.stop()
                self.bombSoundEffect = nil
            }
            
            // 4. Create a new bomb fuse sound effect, then play it.
            let soundFilePath = NSBundle.mainBundle().pathForResource("sliceBombFuse.caf", ofType: nil)!
            let urlToSoundFile = NSURL(fileURLWithPath: soundFilePath)
            let soundEffect = try! AVAudioPlayer(contentsOfURL: urlToSoundFile)
            self.bombSoundEffect = soundEffect
            soundEffect.play()
            
            // 5. Create a particle emitter node, position it so that it's a the end of the bomb image's fuse, and add it to the container.
            let fuseEmitter = SKEmitterNode(fileNamed: "sliceFuse.sks")!
            fuseEmitter.position = CGPoint(x: 76, y: 64)
            enemy.addChild(fuseEmitter)
        }
        else {
            enemy = SKSpriteNode(imageNamed: "penguin")
            self.runAction(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"
        }
        
        // 1. Give the enemy a random position off the bottom edge of the screen.
        let randomPosition = CGPoint(x: RandomInt(64, max: 960), y: -128)
        enemy.position = randomPosition
        
        // 2. Create a random angular velocity, which is how fast something should spin.
        let randomAngularVelocity = CGFloat(RandomInt(-6, max: 6)) / 2.0
        
        // 3. Create a random x velocity (how far to move horizontally) that takes into account the enemy's position
        var randomXVelocity = 0
        if randomPosition.x < 256 { randomXVelocity = RandomInt(8, max: 15) }
        else if randomPosition.x < 512 { randomXVelocity = RandomInt(3, max: 5) }
        else if randomPosition.x < 768 { randomXVelocity = -RandomInt(3, max: 5) }
        else { randomXVelocity = -RandomInt(8, max: 15) }
        
        // 4. Create a random y velocity just to make things fly at different speeds.
        let randomYVelocity = RandomInt(24, max: 32)
        
        // 5. Give all enemiesa circular physics body where the collisionBitMask is set to 0 so they don't collide.
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64.0)
        enemy.physicsBody!.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody!.angularVelocity = randomAngularVelocity
        enemy.physicsBody!.collisionBitMask = 0
        
        self.addChild(enemy)
        self.activeEnemies.append(enemy)
        
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
    
    func endGame(triggeredByBomb triggeredByBomb: Bool) {
        if self.gameEnded { return }
        
        self.gameEnded = true
        self.physicsWorld.speed = 0
        self.userInteractionEnabled = false
        
        if self.bombSoundEffect != nil {
            self.bombSoundEffect.stop()
            self.bombSoundEffect = nil
        }
        
        if triggeredByBomb {
            self.livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            self.livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            self.livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }
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
        // 1. If we have fewer than 2 points in our array, we don't have enough data to draw a line so it needs to clear the shapes and exit the method.
        guard activeSlicePoints.count >= 2 else {
            self.activeSliceBG.path = nil
            self.activeSliceFG.path = nil
            return
        }
        
        // 2. If we have more than 12 slice points in our array, we need to remove the oldest ones until we have at most 12 - this stops the swipe shapes from becoming too long.
        while self.activeSlicePoints.count > 12 { self.activeSlicePoints.removeAtIndex(0) }
        
        // 3. It needs to start its line at the postiion of the first swipe point, then go through each of the others drawing lines to each point.
        let bezierPath = UIBezierPath()
        bezierPath.moveToPoint(self.activeSlicePoints.first! as CGPoint)
        
        for index in 1 ..< self.activeSlicePoints.count {
            bezierPath.addLineToPoint(self.activeSlicePoints[index])
        }
        
        // 4. Finally, it needs to update the slice shape paths so they get drawn using their designs. i.e., line width and color.
        self.activeSliceBG.path = bezierPath.CGPath
        self.activeSliceFG.path = bezierPath.CGPath
    }
    
    func subtractLife() {
        --self.remainingLives
        
        self.runAction(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life: SKSpriteNode!
        
        if self.remainingLives == 2 { life = self.livesImages[0] }
        else if self.remainingLives == 1 { life = self.livesImages[1] }
        else {
            life = self.livesImages[2]
            self.endGame(triggeredByBomb: false)
        }
        
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        
        life.xScale = 1.3
        life.yScale = 1.3
        life.runAction(SKAction.scaleTo(1, duration: 0.1))
    }
    
    func tossEnemies() {
        if self.gameEnded { return }
        
        self.popupTimeBetweenSpawn *= 0.991
        self.delayToCreateChainedEnemies *= 0.99
        self.physicsWorld.speed *= 1.02
        
        let sequenceType = self.sequenceOfEnemiesToCreate[self.sequencePositionCurrently]
        switch sequenceType {
            case .OneNoBomb:
                self.createEnemy(.Never)
            case .One:
                self.createEnemy()
            case .TwoWithOneBomb:
                self.createEnemy(.Never)
                self.createEnemy(.Always)
            case .Two:
                self.createEnemy()
                self.createEnemy()
            case .Three:
                self.createEnemy()
                self.createEnemy()
                self.createEnemy()
            case .Four:
                self.createEnemy()
                self.createEnemy()
                self.createEnemy()
                self.createEnemy()
            case .Chain:
                self.createEnemy()
                runAfterDelay(self.delayToCreateChainedEnemies / 5.0, block: { [unowned self] () -> Void in
                    self.createEnemy()
                })
                runAfterDelay(self.delayToCreateChainedEnemies / 5.0 * 2, block: { [unowned self] () -> Void in
                    self.createEnemy()
                })
                runAfterDelay(self.delayToCreateChainedEnemies / 5.0 * 3, block: { [unowned self] () -> Void in
                    self.createEnemy()
                })
                runAfterDelay(self.delayToCreateChainedEnemies / 5.0 * 4, block: { [unowned self] () -> Void in
                    self.createEnemy()
                })
            case .FastChain:
                self.createEnemy()
                runAfterDelay(self.delayToCreateChainedEnemies / 10.0, block: { [unowned self] () -> Void in
                    self.createEnemy()
                })
                runAfterDelay(self.delayToCreateChainedEnemies / 10.0 * 2, block: { [unowned self] () -> Void in
                    self.createEnemy()
                })
                runAfterDelay(self.delayToCreateChainedEnemies / 10.0 * 3, block: { [unowned self] () -> Void in
                    self.createEnemy()
                })
                runAfterDelay(self.delayToCreateChainedEnemies / 10.0 * 4, block: { [unowned self] () -> Void in
                    self.createEnemy()
                })
        }
        ++self.sequencePositionCurrently
        self.nextSequenceQueued = false
    }
}
