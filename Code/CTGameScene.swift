//  CTGameScene.swift
//  Chase2D
//
//  Created by Roshan Thapa Magar on 10/26/24.
//

import SpriteKit
import GameplayKit

class CTGameScene: SKScene {
    weak var context: CTGameContext?
    
    var playerCarEntity: CTPlayerCarEntity?
    var pedCarSpawner: CTPedAINode?
    var copCarSpawner: CTCopAINode?
    var pedCarEntities: [CTPedCarEntity] = []
    var copCarEntities: [CTCopCarEntity] = []
    var cameraNode: SKCameraNode?
    var gameInfo: CTGameInfo
    
    
    let GAME_SPEED_INCREASE_RATE = 0.01

    
    required init?(coder aDecoder: NSCoder) {
        self.gameInfo = CTGameInfo()
        super.init(coder: aDecoder)
        self.view?.isMultipleTouchEnabled = true
        self.addChild(gameInfo.scoreLabel)
        self.addChild(gameInfo.timeLabel)
        self.addChild(gameInfo.healthLabel)
        self.addChild(gameInfo.gameOverLabel)
        self.addChild(gameInfo.healthIndicator)
        self.addChild(gameInfo.speedometer)
        self.addChild(gameInfo.speedometerBG)
    }
        
    override func didMove(to view: SKView) {
        guard let context else {
            return
        }
        
        // for collision
        physicsWorld.contactDelegate = self
        
        view.showsFPS = true
        view.showsPhysics = true
        
        prepareGameContext()
        prepareStartNodes()
        
        
       
        context.stateMachine?.enter(CTGamePlayState.self)
    }
    
    override func update(_ currentTime: TimeInterval) {
       
        if(gameInfo.gameOver){
            context?.stateMachine?.enter(CTGameOverState.self)
        }
        context?.stateMachine?.update(deltaTime: currentTime)
        
        gameInfo.updateScore(phoneRuntime: currentTime)
        
        // Text UI Components
        gameInfo.scoreLabel.position = CGPoint(x: cameraNode!.position.x + 15, y: cameraNode!.position.y + 90)
        gameInfo.timeLabel.position = CGPoint(x: cameraNode!.position.x - 15, y: cameraNode!.position.y + 90)
        gameInfo.gameOverLabel.position = CGPoint(x: cameraNode!.position.x, y: cameraNode!.position.y + 50)
        
        gameInfo.healthLabel.position = CGPoint(x: cameraNode!.position.x + 50, y: cameraNode!.position.y - 50 )
        gameInfo.setHealthLabel(value: gameInfo.playerHealth)
        
        // Non-text UI components
        gameInfo.healthIndicator.position = CGPoint(x: cameraNode!.position.x + 50, y: cameraNode!.position.y - 50)
        gameInfo.healthIndicator.alpha = 0.5

        gameInfo.speedometer.position = CGPoint(x: cameraNode!.position.x, y: cameraNode!.position.y - 110)
        let velocity = playerCarEntity?.carNode.physicsBody?.velocity
        let speed = sqrt(velocity!.dx * velocity!.dx + velocity!.dy * velocity!.dy)
        gameInfo.speedometerBG.position = CGPoint(x: cameraNode!.position.x + gameInfo.updateSpeed(speed: speed), y: cameraNode!.position.y - 110)
        
        updateCopCarComponents()
        updatePedCarComponents()
    }
    
    func updatePedCarComponents(){

        for pedCarEntity in pedCarEntities {
            
            pedCarEntity.updateCurrentTarget()
            
             if let trackingComponent = pedCarEntity.component(ofType: CTSelfDrivingComponent.self) {
                 trackingComponent.follow(target: pedCarEntity.currentTarget)
                trackingComponent.avoidObstacles()
            }
            if let drivingComponent = pedCarEntity.component(ofType: CTDrivingComponent.self) {
                drivingComponent.drive(driveDir: .forward)
            }
        }
    }
    
    func updateCopCarComponents(){
        // copCar drive
        for copCarEntity in copCarEntities{
            
            let distanceWithPlayer = playerCarEntity?.carNode.calculateSquareDistance(pointA: copCarEntity.carNode.position, pointB: playerCarEntity?.carNode.position ?? CGPoint(x: 0, y: 0)) ?? 0
            
            if distanceWithPlayer >= gameInfo.ITEM_DESPAWN_DIST * gameInfo.ITEM_DESPAWN_DIST {
                copCarEntity.carNode.removeFromParent()
                if let index =  copCarEntities.firstIndex(of: copCarEntity) {
                    copCarEntities.remove(at: index)
                }
                gameInfo.numberOfCops -= 1
                continue;
            }
            
            if let trackingComponent = copCarEntity.component(ofType: CTSelfDrivingComponent.self) {
                trackingComponent.follow(target: playerCarEntity?.carNode.position ?? CGPoint(x: 0.0, y: 0.0))
                trackingComponent.avoidObstacles()
            }
            if let drivingComponent = copCarEntity.component(ofType: CTDrivingComponent.self) {
                drivingComponent.drive(driveDir: .forward)
            }
        }
    }
    
    func prepareGameContext(){
    
        guard let context else {
            return
        }

        context.scene = scene
        context.updateLayoutInfo(withScreenSize: size)
        context.configureStates()
    }
    
    func prepareStartNodes() {
        guard let context else {
            return
        }
        
        // set player car from scene
//        let playerCarNode = CTCarNode(imageNamed: "red", size: (context.layoutInfo.playerCarSize) )
        let playerCarNode = CTCarNode(imageNamed: "playerCar", size: (context.layoutInfo.playerCarSize) )
        playerCarEntity = CTPlayerCarEntity(carNode: playerCarNode)
        playerCarEntity?.gameInfo = gameInfo
        playerCarEntity?.prepareComponents()
        addChild(playerCarNode)
        
       
        // spawns ped cars
        pedCarSpawner = self.childNode(withName: "PedAI") as? CTPedAINode
        pedCarSpawner?.context = context
        pedCarSpawner?.populateAI()
        
        // spawns cop cars
        copCarSpawner = self.childNode(withName: "CopAI") as? CTCopAINode
        copCarSpawner?.context = context
        copCarSpawner?.populateAI()
        
        
        // camera node
        let cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        addChild(cameraNode)
        self.cameraNode = cameraNode
        camera = self.cameraNode
        
        let zoomInAction = SKAction.scale(to: 0.35, duration: 0.2)
        // debug camera
//        let zoomInAction = SKAction.scale(to: 1, duration: 0.2)
        cameraNode.run(zoomInAction)
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let state = context?.stateMachine?.currentState as? CTGamePlayState else {
            return
        }
        state.handleTouchStart(touches)
    }
    
    // only for testing purpose
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let state = context?.stateMachine?.currentState as? CTGamePlayState else {
            return
        }
        state.handleTouchEnded(touch)
    }
}


extension CTGameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        let categoryA = contact.bodyA.categoryBitMask
        let categoryB = contact.bodyB.categoryBitMask
        
        let collision = categoryA | categoryB
        
        if collision == (CTPhysicsCategory.car  | CTPhysicsCategory.building) ||
            collision == (CTPhysicsCategory.car | CTPhysicsCategory.enemy) ||
            collision == (CTPhysicsCategory.car | CTPhysicsCategory.ped) {
            
            let carNode = (contact.bodyA.categoryBitMask == CTPhysicsCategory.car) ? contact.bodyA.node as? CTCarNode : contact.bodyB.node as? CTCarNode
            let colliderNode = (contact.bodyA.categoryBitMask != CTPhysicsCategory.car) ? contact.bodyA.node : contact.bodyB.node
            
            
            let carVelocityMag = pow(carNode?.physicsBody?.velocity.dx ?? 0.0, 2) + pow(carNode?.physicsBody?.velocity.dy ?? 0.0, 2)
            let colliderVelocityMag:CGFloat = pow(colliderNode?.physicsBody?.velocity.dx ?? 0.0, 2) + pow(colliderNode?.physicsBody?.velocity.dy ?? 0.0, 2)
            
         // impact force depends on the relative velocity
               
            gameInfo.playerHealth -= abs(carVelocityMag - colliderVelocityMag) * 0.0001
            
            if(gameInfo.playerHealth <= 0){
                gameInfo.playerHealth = 0
                gameInfo.setGameOver()
            }
        }
        
    }
}
