//  CTGameContext.swift
//  Chase2D
//
//  Created by Roshan Thapa Magar on 10/26/24.
//

import Combine
import GameplayKit

class CTGameContext: GameContext{
    var gameScene: CTGameScene? {
        scene as? CTGameScene
    }
    let gameMode: GameModeType
//    var gameInfo: CTGameInfo
    var layoutInfo: CTLayoutInfo = .init(screenSize: .zero)
    
    private(set) var stateMachine: GKStateMachine?
    
    init(dependencies: Dependencies, gameMode: GameModeType) {
//        self.gameInfo = gameInfo
        self.gameMode = gameMode
        super.init(dependencies: dependencies)
    }
        
    func updateLayoutInfo(withScreenSize size: CGSize){
        layoutInfo = CTLayoutInfo(screenSize: size)
    }
    
    func configureStates() {
        guard let gameScene else { return }
        print("did configure states")
        stateMachine = GKStateMachine(states: [
            CTGameIdleState(scene: gameScene, context: self),
            CTGameOverState(scene: gameScene, context: self),
        ])
    }
}



