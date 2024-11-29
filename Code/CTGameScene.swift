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
    var copTruckEntities: [CTCopTruckEntity] = []
    var copTankEntities: [CTCopTankEntity] = []
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
        
        gameInfo.healthLabel.position = CGPoint(x: cameraNode!.position.x + 40, y: cameraNode!.position.y - 80 )
        gameInfo.setHealthLabel(value: gameInfo.playerHealth)
        
        // Non-text UI components
        gameInfo.healthIndicator.position = CGPoint(x: cameraNode!.position.x + 45, y: cameraNode!.position.y - 50)
        gameInfo.healthIndicator.alpha = 0.5
        

        gameInfo.speedometer.position = CGPoint(x: cameraNode!.position.x, y: cameraNode!.position.y - 100)
        
        // to preserve the aspect ration we are gonna set the height based on the
        gameInfo.speedometer.size = CGSize(width: self.size.width, height: 100.0)
        let velocity = playerCarEntity?.carNode.physicsBody?.velocity ?? CGVector(dx: 0.0, dy: 0.0)
        // TODO: try not to use sqrt because of performance issues
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        gameInfo.speedometerBG.position = CGPoint(x: cameraNode!.position.x + gameInfo.updateSpeed(speed: speed), y: cameraNode!.position.y - 100)
        
        
        // ai section
        updateCopComponents()
        updatePedCarComponents()
        
        
        // spawn powerup section
        
        // spawn more cash if cash is low
        if(gameInfo.numberOfCashNodesInScene < 20){
            spawnCashNodes(amount:gameInfo.initialCashNumber)
            gameInfo.numberOfCashNodesInScene = gameInfo.numberOfCashNodesInScene + gameInfo.initialCashNumber
        }
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
    
    func updateCopComponents(){
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
            
             // if the health of enemy is very less
            if copCarEntity.carNode.health <= 0.0 {
                 if let healthComponent = copCarEntity.component(ofType: CTHealthComponent.self) {
                     healthComponent.applyDeath()
                 }
                if let index =  copCarEntities.firstIndex(of: copCarEntity) {
                    copCarEntities.remove(at: index)
                }
                gameInfo.numberOfCops -= 1
                continue;
            }
            
            
            if let trackingComponent = copCarEntity.component(ofType: CTSelfDrivingComponent.self) {
                trackingComponent.avoidObstacles()
                trackingComponent.follow(target: playerCarEntity?.carNode.position ?? CGPoint(x: 0.0, y: 0.0))
            }
            if let drivingComponent = copCarEntity.component(ofType: CTDrivingComponent.self) {
                drivingComponent.drive(driveDir: .forward)
            }
            
            if let shootingComponent = copCarEntity.component(ofType: CTShootingComponent.self) {
                shootingComponent.shoot(target: playerCarEntity?.carNode.position ?? CGPoint(x: 0.0, y: 0.0))
            }
            
        }
        for copTruckEntity in copTruckEntities{
            let distanceWithPlayer = playerCarEntity?.carNode.calculateSquareDistance(pointA: copTruckEntity.carNode.position, pointB: playerCarEntity?.carNode.position ?? CGPoint(x: 0, y: 0)) ?? 0
            
            if distanceWithPlayer >= gameInfo.ITEM_DESPAWN_DIST * gameInfo.ITEM_DESPAWN_DIST {
                copTruckEntity.carNode.removeFromParent()
                if let index =  copTruckEntities.firstIndex(of: copTruckEntity) {
                    copTruckEntities.remove(at: index)
                }
                gameInfo.numberOfCops -= 1
                continue;
            }
            
            // if the health of enemy is very less
            if copTruckEntity.carNode.health <= 0.0 {
                 if let healthComponent = copTruckEntity.component(ofType: CTHealthComponent.self) {
                     healthComponent.applyDeath()
                 }
                if let index =  copTruckEntities.firstIndex(of: copTruckEntity) {
                    copTruckEntities.remove(at: index)
                }
                gameInfo.numberOfCops -= 1
                continue;
            }
            
            if let trackingComponent = copTruckEntity.component(ofType: CTSelfDrivingComponent.self) {
                trackingComponent.avoidObstacles()
                trackingComponent.follow(target: playerCarEntity?.carNode.position ?? CGPoint(x: 0.0, y: 0.0))
            }
            if let drivingComponent = copTruckEntity.component(ofType: CTDrivingComponent.self) {
                drivingComponent.drive(driveDir: .forward)
            }
            
            if let shootingComponent = copTruckEntity.component(ofType: CTShootingComponent.self) {
                shootingComponent.shoot(target: playerCarEntity?.carNode.position ?? CGPoint(x: 0.0, y: 0.0))
            }
            
        }
        
        for copTruckEntity in copTankEntities{
            let distanceWithPlayer = playerCarEntity?.carNode.calculateSquareDistance(pointA: copTruckEntity.carNode.position, pointB: playerCarEntity?.carNode.position ?? CGPoint(x: 0, y: 0)) ?? 0
            
            if distanceWithPlayer >= gameInfo.ITEM_DESPAWN_DIST * gameInfo.ITEM_DESPAWN_DIST {
                copTruckEntity.carNode.removeFromParent()
                if let index =  copTankEntities.firstIndex(of: copTruckEntity) {
                    copTruckEntities.remove(at: index)
                }
                gameInfo.numberOfCops -= 1
                continue;
            }
            
            // if the health of enemy is very less
            if copTruckEntity.carNode.health <= 0.0 {
                 if let healthComponent = copTruckEntity.component(ofType: CTHealthComponent.self) {
                     healthComponent.applyDeath()
                 }
                if let index =  copTankEntities.firstIndex(of: copTruckEntity) {
                    copTruckEntities.remove(at: index)
                }
                gameInfo.numberOfCops -= 1
                continue;
            }
            
            if let trackingComponent = copTruckEntity.component(ofType: CTSelfDrivingComponent.self) {
                trackingComponent.avoidObstacles()
                trackingComponent.follow(target: playerCarEntity?.carNode.position ?? CGPoint(x: 0.0, y: 0.0))
            }
            if let drivingComponent = copTruckEntity.component(ofType: CTDrivingComponent.self) {
                drivingComponent.drive(driveDir: .forward)
            }
            
            if let shootingComponent = copTruckEntity.component(ofType: CTShootingComponent.self) {
                shootingComponent.shoot(target: playerCarEntity?.carNode.position ?? CGPoint(x: 0.0, y: 0.0))
            }
            
        }
    }
    
    func spawnCashNodes(amount: Int){
        
        guard let context else { return }
        
        let randomSource = GKRandomSource.sharedRandom()
        
        for _ in 0...amount {
            let randomFloatX = Double(randomSource.nextUniform()) * gameInfo.MAX_PLAYABLE_SIZE - gameInfo.MAX_PLAYABLE_SIZE / 2.0
            let randomFloatY = Double(randomSource.nextUniform()) * gameInfo.MAX_PLAYABLE_SIZE - gameInfo.MAX_PLAYABLE_SIZE / 2.0
            
            let cashNode = CTPowerUpNode(imageNamed: "scoreBoost", nodeSize: context.layoutInfo.powerUpSize)
            cashNode.name = "cash"
            cashNode.position = CGPoint(x: randomFloatX, y: randomFloatY)
            cashNode.zPosition = -1
            addChild(cashNode)
            
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
        
        let zoomInAction = SKAction.scale(to: 0.3, duration: 0.2)
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
        
        // player collision
        // non-damage collision
        if collision == (CTPhysicsCategory.car | CTPhysicsCategory.powerup) {
            
            let colliderNode = (contact.bodyA.categoryBitMask != CTPhysicsCategory.car) ? contact.bodyA.node : contact.bodyB.node
            // add cash if car hits a powerup and remove cash from total
            gameInfo.cashCollected = gameInfo.cashCollected + 1
            gameInfo.numberOfCashNodesInScene = gameInfo.numberOfCashNodesInScene - 1
            colliderNode?.removeFromParent()
            
            // randomly applies one powerup if we collect 5 powerup
            if(gameInfo.cashCollected == 1) {
                activatePowerUp()
                gameInfo.cashCollected = 0
            }
            
        }
        
        
        // if bullet hits anything remove it from the scene
        if categoryB == CTPhysicsCategory.bullet || categoryA == CTPhysicsCategory.bullet {
            print("bullet hit something")
            let bullet = (contact.bodyA.categoryBitMask == CTPhysicsCategory.bullet) ? contact.bodyA.node as? CTBulletNode : contact.bodyB.node as? CTBulletNode
            bullet?.removeFromParent()
        }
        
        // bullet collision
        if collision == (CTPhysicsCategory.bullet | CTPhysicsCategory.car) {
            gameInfo.playerHealth -= 10
        }
        
        
        // damage collision
        if collision == (CTPhysicsCategory.car  | CTPhysicsCategory.building) ||
            collision == (CTPhysicsCategory.car | CTPhysicsCategory.copCar) ||
            collision == (CTPhysicsCategory.car | CTPhysicsCategory.copTruck) ||
            collision == (CTPhysicsCategory.car | CTPhysicsCategory.copTank) ||
            collision == (CTPhysicsCategory.car | CTPhysicsCategory.ped) {
            
            let carNode = (contact.bodyA.categoryBitMask == CTPhysicsCategory.car) ? contact.bodyA.node as? CTCarNode : contact.bodyB.node as? CTCarNode
            let colliderNode = (contact.bodyA.categoryBitMask != CTPhysicsCategory.car) ? contact.bodyA.node : contact.bodyB.node
            
            
            let carVelocityMag = pow(carNode?.physicsBody?.velocity.dx ?? 0.0, 2) + pow(carNode?.physicsBody?.velocity.dy ?? 0.0, 2)
            let colliderVelocityMag:CGFloat = pow(colliderNode?.physicsBody?.velocity.dx ?? 0.0, 2) + pow(colliderNode?.physicsBody?.velocity.dy ?? 0.0, 2)
            
            // impact force depends on the relative velocity
            
            gameInfo.playerHealth -= abs(carVelocityMag - colliderVelocityMag) * 0.000099
            
        }
        
        if(gameInfo.playerHealth <= 0){
            gameInfo.playerHealth = 0
            gameInfo.setGameOver()
        }
        
        
        // enemy damages
        
        // bullet collision
        if  collision == (CTPhysicsCategory.bullet | CTPhysicsCategory.copCar)  ||
                collision == (CTPhysicsCategory.bullet | CTPhysicsCategory.copTank) ||
                collision == (CTPhysicsCategory.bullet | CTPhysicsCategory.copTruck) {
            print("enemy hit by bullet")
            
            let bullet = (contact.bodyA.categoryBitMask == CTPhysicsCategory.bullet) ? contact.bodyA.node as? CTBulletNode : contact.bodyB.node as? CTBulletNode
            
            var enemy: EnemyNode? // Replace `EnemyNode` with your base type if applicable
            
            if contact.bodyA.categoryBitMask == CTPhysicsCategory.copTruck,
               let truck = contact.bodyA.node as? CTCopTruckNode {
                enemy = truck
            } else if contact.bodyB.categoryBitMask == CTPhysicsCategory.copTruck,
                      let truck = contact.bodyB.node as? CTCopTruckNode {
                enemy = truck
            } else if contact.bodyA.categoryBitMask == CTPhysicsCategory.copCar,
                      let car = contact.bodyA.node as? CTCopNode {
                enemy = car
            } else if contact.bodyB.categoryBitMask == CTPhysicsCategory.copCar,
                      let car = contact.bodyB.node as? CTCopNode {
                enemy = car
            }
            
            // Apply health reduction if an enemy was found
            if var enemy = enemy {
                enemy.health -= 10.0
                print(enemy.health)
            }
            
            
        }
        
        
        // damage collision
        if  (categoryA == CTPhysicsCategory.copCar || categoryB == CTPhysicsCategory.copCar) ||
                (categoryA == CTPhysicsCategory.copTank || categoryB == CTPhysicsCategory.copTank) ||
                (categoryA == CTPhysicsCategory.copTruck || categoryB == CTPhysicsCategory.copTruck)
                
        {
            
            var enemy: EnemyNode? // Replace `EnemyNode` with your base type if applicable
            
            if contact.bodyA.categoryBitMask == CTPhysicsCategory.copTruck,
               let truck = contact.bodyA.node as? CTCopTruckNode {
                enemy = truck
            } else if contact.bodyB.categoryBitMask == CTPhysicsCategory.copTruck,
                      let truck = contact.bodyB.node as? CTCopTruckNode {
                enemy = truck
            } else if contact.bodyA.categoryBitMask == CTPhysicsCategory.copCar,
                      let car = contact.bodyA.node as? CTCopNode {
                enemy = car
            } else if contact.bodyB.categoryBitMask == CTPhysicsCategory.copCar,
                      let car = contact.bodyB.node as? CTCopNode {
                enemy = car
            }
            
            
            let colliderNode = (
                contact.bodyA.categoryBitMask == CTPhysicsCategory.copCar   ||
                contact.bodyA.categoryBitMask == CTPhysicsCategory.copTank  ||
                contact.bodyA.categoryBitMask == CTPhysicsCategory.copTruck
            ) ? contact.bodyB.node : contact.bodyA.node
            
            let carVelocityMag = pow(enemy?.physicsBody?.velocity.dx ?? 0.0, 2) + pow(enemy?.physicsBody?.velocity.dy ?? 0.0, 2)
            let colliderVelocityMag:CGFloat = pow(colliderNode?.physicsBody?.velocity.dx ?? 0.0, 2) + pow(colliderNode?.physicsBody?.velocity.dy ?? 0.0, 2)
            
            // Apply health reduction if an enemy was found
            if var enemy = enemy {
                enemy.health -= abs(carVelocityMag - colliderVelocityMag) * 0.00008
                print(enemy.health)
            }
        }
    }
}

extension CTGameScene{
    
    func activatePowerUp() {
        let randomNumber = GKRandomDistribution(lowestValue: 0, highestValue: 5).nextInt()
        switch(randomNumber){
        case 0,1:
            boostHealth()
            break;
        case 2:
            destroyCops()
            break;
        case 3,4,5:
             increaseSpeed()
            break;
        default:
            break;
        }
    }
    
    func boostHealth() {
        gameInfo.playerHealth = gameInfo.playerHealth + 5
        print("boostHealth")
    }
    
    func destroyCops() {
        for copCarEntity in copCarEntities{
            let fadeOutAction = SKAction.fadeOut(withDuration: 1.0)
            copCarEntity.carNode.run(fadeOutAction) {
                if let index =  self.copCarEntities.firstIndex(of: copCarEntity) {
                    copCarEntity.carNode.removeFromParent()
                    self.copCarEntities.remove(at: index)
                    self.gameInfo.numberOfCops -= 1
                }
            }
            
        }
        print("destoryCops")
    }
    
    func increaseSpeed() {
        gameInfo.playerSpeed = gameInfo.playerSpeed + 100
        print("increase Speed")
    }
    
}
