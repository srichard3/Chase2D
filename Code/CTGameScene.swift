//  CTGameScene.swift
//  Chase2D
//
//  Created by Roshan Thapa Magar on 10/26/24.
//

import SpriteKit
import GameplayKit

class CTGameScene: SKScene {
    weak var context: CTGameContext?
    
    var playerCarNode: CTCarNode?
    var cameraNode: SKCameraNode?
    var gameInfo: CTGameInfo
    
    required init?(coder aDecoder: NSCoder) {
        self.gameInfo = CTGameInfo()
        super.init(coder: aDecoder)
        self.view?.isMultipleTouchEnabled = true
//        fatalError("init(coder:) has not been implemented")
    }

//    init(context: CTGameContext, size: CGSize) {
//        self.context = context
//        super.init(size: size)
//    }
        
    override func didMove(to view: SKView) {
        guard let context else {
            return
        }
        
        view.showsFPS = true
        view.showsPhysics = true
        
        addChild(gameInfo.scoreLabel) //not sure if this belongs here -j
        
        prepareGameContext()
        prepareStartNodes()
        
        
        // set player car from scene
        self.playerCarNode = childNode(withName: "CTCarNode") as? CTCarNode
        
        context.stateMachine?.enter(CTGameIdleState.self)
        
    }
    
    override func update(_ currentTime: TimeInterval) {
        context?.stateMachine?.update(deltaTime: currentTime)
        gameInfo.updateScore(deltaTime: currentTime)
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
        
        let center = CGPoint(x: size.width / 2.0 - context.layoutInfo.playerCarSize.width / 2.0,
                             y: size.height / 2.0)
        
        let cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        addChild(cameraNode)
        self.cameraNode = cameraNode
        camera = self.cameraNode
        
        let zoomInAction = SKAction.scale(to: 0.3, duration: 0.2)
        cameraNode.run(zoomInAction)
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let state = context?.stateMachine?.currentState as? CTGameIdleState else {
            return
        }
        state.handleTouchStart(touches)
    }
    
    // only for testing purpose
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let state = context?.stateMachine?.currentState as? CTGameIdleState else {
            return
        }
        state.handleTouchEnded(touch)
    }
}
