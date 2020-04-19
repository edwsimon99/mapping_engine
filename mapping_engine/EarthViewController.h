//
//  EarthViewController.h
//  earth
//
//  Created by Edward Simon on 2/10/20.
//  Copyright © 2020 Edward Simon. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import <SpriteKit/SpriteKit.h>

@interface EarthViewController : UIViewController

@property (nonatomic, strong) UIRotationGestureRecognizer *rotationGestureRecognizer;
@property (nonatomic, unsafe_unretained) CGFloat rotationAngleInRadians;

@property (nonatomic, strong) UIPinchGestureRecognizer *pinchGestureRecognizer;
@property (nonatomic, unsafe_unretained) CGFloat currentScale;

@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;

@property SCNView *earthView;

@property SCNNode *globeNode;
@property SCNNode *pathNode;
@property SCNNode *spaceJunkNode;

@property SCNNode *cameraNode;
@property SCNNode *cameraOrbit;

@property SKLabelNode *lat;
@property SKLabelNode *lon;

@end
