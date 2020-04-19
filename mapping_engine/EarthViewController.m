//
//  EarthViewController.m
//  earth
//
//  Created by Edward Simon on 2/16/20.
//  Copyright © 2020 Edward Simon. All rights reserved.
//

#import "EarthViewController.h"
#import "UIKit/UIColor.h"
#import "MapKit/MapKit.h"

@implementation EarthViewController

static const double deg2rad = M_PI / 180.0;

static bool drawit = true;
static double last_lat = 1000;
static double last_lon = 1000;

- (void)convertPointToTextureCoordinates:(NSArray *)point  textureSize:(CGSize)size x:(int *)x y:(int *)y
{
    NSNumber *lon_v = point[0];
    NSNumber *lat_v = point[1];
    double lon = lon_v.doubleValue;
    double lat = lat_v.doubleValue;
    double width_stride = size.width / 360.0;
    double height_stride = size.height / 180.0;
    
    *x = (lon > 0 ? size.width/2 + ceil(lon * width_stride) : size.width/2 - ceil(fabs(lon) * width_stride));
    *y = (lat > 0 ? size.height/2 - ceil(lat * height_stride) : size.height/2 + ceil(fabs(lat) * height_stride));
}

- (void)drawCoordinates:(NSArray *)coords context:(CGContextRef)context textureSize:(CGSize)size
{
    int x, y;
    
    CGContextBeginPath(context);
    
    [self convertPointToTextureCoordinates:coords[0]  textureSize:size x:&x y:&y];
    CGContextMoveToPoint(context, x, y);
    
    for (int j = 1; j < (coords.count - 1); ++j)
    {
        [self convertPointToTextureCoordinates:coords[j]  textureSize:size x:&x y:&y];
        CGContextAddLineToPoint(context, x, y);
    }
    
    CGContextStrokePath(context);
}

- (void) procCentroidLabelsCSV:(NSString *)filepath fontSize:(CGFloat)fontSize fontColor:(UIColor *)fontColor context:(CGContextRef)context textureSize:(CGSize)size
{
    NSArray *rows = nil;
    {
        NSDataAsset *asset = [[NSDataAsset alloc] initWithName:filepath];
        NSString* csvString = [[NSString alloc] initWithData:[asset data] encoding:NSUTF8StringEncoding];
        rows = [csvString componentsSeparatedByString:@"\n"];
    }
    int x, y;
    
    for (int i = 0; i < rows.count; i ++)
    {
        NSString* row = rows[i];
        NSArray* columns = [row componentsSeparatedByString:@"\t"];
        if (columns.count < 4)
            break;
        NSNumber *lon = [NSNumber numberWithDouble:[columns[2] doubleValue]];
        NSNumber *lat = [NSNumber numberWithDouble:[columns[1] doubleValue]];
        NSArray *point = @[lon, lat];
        [self convertPointToTextureCoordinates:point textureSize:size x:&x y:&y]; //got the centroid location
        UIFont *font = [UIFont systemFontOfSize:fontSize];
        NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
        style.alignment = NSTextAlignmentCenter;
        NSDictionary *attrsDictionary = @{
            NSFontAttributeName : font,
            NSParagraphStyleAttributeName : style,
            NSForegroundColorAttributeName : fontColor,
            NSStrokeWidthAttributeName : @-3,
            NSStrokeColorAttributeName : [UIColor blackColor]  //outline color
        };
        NSString *label = columns[3];
        CGSize size = [label sizeWithAttributes:@{NSFontAttributeName:font}];
        [label drawAtPoint:CGPointMake(x - size.width / 2, y - size.height / 2) withAttributes:attrsDictionary];
    }
}

- (void)procRegionPolygonsGeoJson:(NSString *)filepath context:(CGContextRef)context textureSize:(CGSize)size
{
    NSDictionary *jsonObject = nil;
    NSError *jsonError = nil;
    {
        NSDataAsset * asset = [[NSDataAsset alloc] initWithName:filepath];
        NSData *jsonData = [asset data];
        jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&jsonError];
    }
    
    if(jsonObject != nil)
    {
        if(! [[jsonObject objectForKey:@"features"] isEqual:@""]) {

            NSMutableArray *array = [jsonObject objectForKey:@"features"];

            for(int z = 0; z < array.count; ++z)
            {
                NSDictionary *dicr = array[z];
                NSDictionary *geometry = [dicr objectForKey:@"geometry"];
                NSString *geometry_type = [geometry objectForKey:@"type"];
                NSArray *coords_container = [geometry objectForKey:@"coordinates"];
                
                if ([geometry_type  isEqual: @"Polygon"])
                {
                    [self drawCoordinates:coords_container[0] context:context  textureSize:size];
                }
                else if ([geometry_type  isEqual: @"MultiPolygon"])
                {
                    for (int i = 0; i < coords_container.count; ++i)
                    {
                        [self drawCoordinates:coords_container[i][0] context:context  textureSize:size];
                    }
                }
            }
        }
    }
}

- (UIImage *)createOverlays:(NSString *)filepath rebuild:(BOOL)rebuild
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Image.png"];
    if ([fileManager fileExistsAtPath:filePath]){
        NSLog(@"File Exists");
        if (! rebuild)
            return [UIImage imageNamed:filePath];
    }
    else
    {
        NSLog(@"File Doesn't Exists");
    }
    UIImage *image = [UIImage imageNamed:filepath];
    CGSize sz = image.size;
    
    UIGraphicsBeginImageContextWithOptions(sz, YES, 1);
    
    [image drawAtPoint:CGPointMake(0,0)];  //Draw the original image as the background
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetStrokeColorWithColor(context, [[UIColor colorWithRed:0.3 green:0.2 blue:0.1 alpha:1.0] CGColor]);

    CGContextSetLineWidth(context, 1.0f);
    
    [self procRegionPolygonsGeoJson:@"us-states" context:context textureSize:sz];
    [self procRegionPolygonsGeoJson:@"aus_state" context:context textureSize:sz];
    [self procRegionPolygonsGeoJson:@"mx_states" context:context textureSize:sz];
    [self procRegionPolygonsGeoJson:@"canada_provinces" context:context textureSize:sz];
    [self procRegionPolygonsGeoJson:@"uk_country" context:context textureSize:sz];
    [self procRegionPolygonsGeoJson:@"br_states" context:context textureSize:sz];
    [self procRegionPolygonsGeoJson:@"argentina_provinces" context:context textureSize:sz];
    [self procRegionPolygonsGeoJson:@"russia" context:context textureSize:sz];

    CGContextSetLineWidth(context, 2.5f);
    CGContextSetStrokeColorWithColor(context, [[UIColor blackColor] CGColor]);

    [self procRegionPolygonsGeoJson:@"custom" context:context textureSize:sz];  //world
    
    UIColor *countryFontColor = [UIColor whiteColor];
    UIColor *stateFontColor = [UIColor yellowColor];
    
    [self procCentroidLabelsCSV:@"country_centroids" fontSize:30 fontColor:countryFontColor context:context textureSize:sz];
    [self procCentroidLabelsCSV:@"state_centroids" fontSize:25 fontColor:stateFontColor context:context textureSize:sz];
    [self procCentroidLabelsCSV:@"canada_centroids" fontSize:25 fontColor:stateFontColor context:context textureSize:sz];
        
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Save image.
    [UIImagePNGRepresentation(image) writeToFile:filePath atomically:YES];
    
    return image;
}

- (void)addGlobe:(short)segment_count rebuild:(bool)rebuild countries:(bool)countries
{
    if (countries)
    {
        UIImage *countries = [UIImage imageNamed:@"color8k"];

        SCNSphere *graySphere = [SCNSphere sphereWithRadius:5.7];
        graySphere.firstMaterial.diffuse.contents = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.000];
        
        SCNNode *graySphereNode = [SCNNode nodeWithGeometry:graySphere];
        graySphereNode.opacity = 0.5;
        [_earthView.scene.rootNode addChildNode:graySphereNode];
        
        SCNSphere *sphere = [SCNSphere sphereWithRadius:5.7];
        sphere.segmentCount = segment_count;
        sphere.firstMaterial.diffuse.contents = countries;
        _globeNode = [SCNNode nodeWithGeometry:sphere];
    }
    else
    {
        UIImage *earth = [self createOverlays:@"earth16k" rebuild:rebuild];

        SCNSphere *sphere = [SCNSphere sphereWithRadius:5.7];
        sphere.segmentCount = segment_count;
        sphere.firstMaterial.diffuse.contents = earth;
        _globeNode = [SCNNode nodeWithGeometry:sphere];
    }
    _globeNode.name = @"globe";
    [_earthView.scene.rootNode addChildNode:_globeNode];
}

- (void)addCrossHair
{
    SKView *targetView = [[SKView alloc] initWithFrame:CGRectMake(0, 0, 121, 121)];
    //targetView.asynchronous = YES;
    targetView.center = self.view.center;
    targetView.backgroundColor = [SKColor clearColor];
    SKScene *targetScene = [SKScene sceneWithSize:CGSizeMake(121, 121)];
    targetScene.backgroundColor = [SKColor clearColor];
    targetView.allowsTransparency = YES;
    [targetView presentScene:targetScene];
    targetView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
                                  UIViewAutoresizingFlexibleLeftMargin |
                                  UIViewAutoresizingFlexibleBottomMargin |
                                  UIViewAutoresizingFlexibleRightMargin;
    [_earthView addSubview:targetView];
    
    SKShapeNode *circle = [SKShapeNode shapeNodeWithCircleOfRadius:35]; // Size of Circle = Radius setting.
    circle.position = CGPointMake(61, 61); //self.view.center;  //touch location passed from touchesBegan.
    circle.name = @"targetCircle";
    circle.strokeColor = [SKColor redColor];
    circle.glowWidth = 1.0;
    circle.fillColor = [SKColor clearColor];
    [targetView.scene addChild:circle];
    
    SKShapeNode *circle2 = [SKShapeNode shapeNodeWithCircleOfRadius:5]; // Size of Circle = Radius setting.
    circle2.position = CGPointMake(61, 61); //self.view.center;  //touch location passed from touchesBegan.
    circle2.name = @"targetInnerCircle";
    circle2.strokeColor = [SKColor redColor];
    circle2.glowWidth = 1.0;
    circle2.fillColor = [SKColor clearColor];
    [targetView.scene addChild:circle2];
    
    SKShapeNode *cross = [SKShapeNode node];
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 61.0, 20.0);
    CGPathAddLineToPoint(path, NULL, 61.0, 58.0);
    CGPathMoveToPoint(path, NULL, 61.0, 66.0);
    CGPathAddLineToPoint(path, NULL, 61.0, 100.0);
    CGPathMoveToPoint(path, NULL, 20.0, 61.0);
    CGPathAddLineToPoint(path, NULL, 58.0, 61.0);
    CGPathMoveToPoint(path, NULL, 64.0, 61.0);
    CGPathAddLineToPoint(path, NULL, 100.0, 61.0);
    cross.path = path;
    cross.strokeColor = [SKColor redColor];
    cross.glowWidth = 1.0;
    [targetView.scene addChild:cross];
    
    NSString *latStr = [NSString stringWithFormat:@"%3.6f", 0.0];
    _lat = [SKLabelNode labelNodeWithText:latStr];
    _lat.fontSize = 18;
    _lat.fontName = @"AvenirNext-Bold";
    _lat.fontColor = [SKColor whiteColor];
    _lat.position = CGPointMake(61, 103);
    _lat.zPosition = 2;
    
    SKSpriteNode *backgroundLat =
        [SKSpriteNode spriteNodeWithColor:[UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.5] size:CGSizeMake(121, 20)];
    backgroundLat.position = CGPointMake(61, 111);
    backgroundLat.zPosition = 1;

    [targetView.scene addChild:backgroundLat];
    [targetView.scene addChild:_lat];

    NSString *lonStr = [NSString stringWithFormat:@"%3.6f", 0.0];
    _lon = [SKLabelNode labelNodeWithText:lonStr];
    _lon.fontSize = 18;
    _lon.fontName = @"AvenirNext-Bold";
    _lon.fontColor = [SKColor whiteColor];
    _lon.position = CGPointMake(61, 3);
    _lon.zPosition = 2;
    
    SKSpriteNode *backgroundLon =
        [SKSpriteNode spriteNodeWithColor:[UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.5] size:CGSizeMake(121, 20)];
    backgroundLon.position = CGPointMake(61, 10);
    backgroundLon.zPosition = 1;

    [targetView.scene addChild:backgroundLon];
    [targetView.scene addChild:_lon];
}

-(void)displayLatLon
{
    NSNumber *searchMode = [NSNumber numberWithLong:SCNHitTestSearchModeAll];
    NSDictionary *optionsDictionary = @{
        SCNHitTestOptionSearchMode: searchMode
    };

    CGPoint center = _earthView.center;
    NSArray<SCNHitTestResult *> *results = [_earthView hitTest:center options:optionsDictionary];
    for (int i = 0; i < results.count; ++i)
    {
        if ([results[i].node.name isEqual: @"globe"])
        {
            NSInteger channel = results[i].node.geometry.firstMaterial.diffuse.mappingChannel;
            CGPoint texcoord = [results[i] textureCoordinatesWithMappingChannel:channel];
            
            double lat, lon;
            
            lon = texcoord.x * 360.0;
            if (lon > 180.0)
                lon -= 180.0;
            else
                lon = -(180 - lon);
            
            lat = texcoord.y * 180.0;
            if (lat > 90.0)
                lat = -(lat - 90.0);
            else
                lat = 90.0 - lat;
            
            NSString *latStr = [NSString stringWithFormat:@"%3.6f", lat];
            NSString *lonStr = [NSString stringWithFormat:@"%3.6f", lon];

            _lat.text = latStr;
            _lon.text = lonStr;
            
            if (drawit)
            {
                if (! _pathNode)
                {
                    _pathNode = [SCNNode node];
                    [_earthView.scene.rootNode addChildNode:_pathNode];
                }
                SCNNode *sphere = [self addSphere:0.1 lat:lat lon:lon radius:0.06 color:[UIColor yellowColor]];
                [_pathNode addChildNode:sphere];
                
                if (last_lat != 1000 && last_lon != 1000)
                {
                    SCNVector3 p1 = [self spherical2cartesian:0.1 lat:last_lat lon:last_lon];
                    SCNVector3 p2 = [self spherical2cartesian:0.1 lat:lat lon:lon];
                    
                    SCNNode *segment = [self cylVector:p1 to:p2];
                    [_pathNode addChildNode:segment];
                }
                
                last_lat = lat;
                last_lon = lon;
            }
        }
    }
}

-(SCNNode *)cylVector:(SCNVector3)from to:(SCNVector3)to
{
    //SCNVector3 vector = to - from;
    SCNVector3 vector = SCNVector3Make(to.x - from.x, to.y - from.y, to.z - from.z);
    //length = vector.length()
    double length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z);

//    SCNCylinder *cylinder = [SCNCylinder cylinderWithRadius:0.035 height:length];
//    cylinder.radialSegmentCount = 6;
//    cylinder.firstMaterial.diffuse.contents = [UIColor colorWithRed:0 green:0 blue:1 alpha:0.7];
//    cylinder.firstMaterial.emission.contents = [UIColor blueColor];
//
//    SCNNode *node = [SCNNode nodeWithGeometry:cylinder];
    SCNTube *shape = [SCNTube tubeWithInnerRadius:0.02 outerRadius:0.03 height:length];
    shape.firstMaterial.diffuse.contents = [UIColor colorWithRed:0 green:0 blue:1 alpha:0.7];
    SCNNode *node = [SCNNode nodeWithGeometry:shape];
    node.name = @"tube";
    
    //node.position = (to + from) / 2
    node.position = SCNVector3Make((to.x + from.x)/2, (to.y + from.y)/2, (to.z + from.z)/2);
    
    node.eulerAngles = SCNVector3Make(M_PI/2, acos((to.z-from.z)/length), atan2((to.y-from.y), (to.x-from.x) ));

    return node;
}

- (void) handleTap:(UIGestureRecognizer*)params
{
    static int counter = 1;
    static bool countries = false;
    
    if (counter++ % 2 == 0)
    {
        countries = !countries;
        [_globeNode removeFromParentNode];
        
        [self addGlobe:96 rebuild:NO countries:countries];
    }
    
    // check what nodes are tapped
    CGPoint p = [params locationInView:_earthView];
    NSArray *hitResults = [_earthView hitTest:p options:nil];
    
    // check that we clicked on at least one object
    if([hitResults count] > 0){
        // retrieved the first clicked object
        SCNHitTestResult *result = [hitResults objectAtIndex:0];
        
        // get its material
        SCNMaterial *material = result.node.geometry.firstMaterial;
        
        // highlight it
        [SCNTransaction begin];
        [SCNTransaction setAnimationDuration:0.5];
        
        // on completion - unhighlight
        [SCNTransaction setCompletionBlock:^{
            [SCNTransaction begin];
            [SCNTransaction setAnimationDuration:0.5];
            
            material.emission.contents = [UIColor blackColor];
            
            [SCNTransaction commit];
            
        }];
        
        drawit = !drawit;

        if (drawit)
        {
            //NSLog(@"spaceJunk.count: %lu", self.spaceJunkNode.childNodes.count);

            material.emission.contents = [UIColor blueColor];

            last_lat = 1000;
            last_lon = 1000;
            
            if (_spaceJunkNode)
            {
                [_spaceJunkNode removeFromParentNode];
                _spaceJunkNode = nil;
            }
        }
        else
        {
            [self addSpaceJunk];
            material.emission.contents = [UIColor redColor];
        }
   
       
        [SCNTransaction commit];
    }
}

-(void) handlePan:(UIPanGestureRecognizer *)params
{
    CGPoint translation = [params translationInView:_earthView];
    //NSLog(@"translation x: %f  y:  %f", translation.x, translation.y);
    float y = _cameraOrbit.eulerAngles.y - translation.x/300 * deg2rad;
    float x = _cameraOrbit.eulerAngles.x - translation.y/300 * deg2rad;
    _cameraOrbit.eulerAngles = SCNVector3Make(x, y, 0);
    
    if (params.state == UIGestureRecognizerStateEnded)
        [self displayLatLon];
}

- (void) handleRotations:(UIRotationGestureRecognizer *)params
{
    _cameraNode.rotation = SCNVector4Make(0, 0, 1, _rotationAngleInRadians + params.rotation);

    if (params.state == UIGestureRecognizerStateEnded)
        _rotationAngleInRadians += params.rotation;
}

- (void) handleLongPress:(UILongPressGestureRecognizer *)params
{
    if (params.state == UIGestureRecognizerStateEnded)
    {
        if (_pathNode)
        {
            [_pathNode removeFromParentNode];
            _pathNode = nil;
            
            last_lat = 1000;
            last_lon = 1000;
        }
    }
}

- (void) handlePinches:(UIPinchGestureRecognizer*)params
{
    if (params.state == UIGestureRecognizerStateEnded)
        _currentScale = params.scale;
    else if (params.state == UIGestureRecognizerStateBegan && _currentScale != 0.0f)
        params.scale = _currentScale;
    
    if (params.scale != NAN && params.scale != 0.0)
    {
        if (params.scale > 2.63)
            params.scale = 2.63;
        else if (params.scale < 0.32)
            params.scale = 0.32;
                
        float scale = 1/params.scale;
        
        _cameraOrbit.scale = SCNVector3Make(scale, scale, scale);
    }
}

- (void)addCamera
{
    _cameraNode = [SCNNode node];
    _cameraNode.camera = [SCNCamera camera];
    _cameraNode.camera.zNear = 0;
    _cameraNode.camera.zFar = 400;
    _cameraNode.position = SCNVector3Make(0, 0, 30);
    SCNLookAtConstraint *constraint = [SCNLookAtConstraint lookAtConstraintWithTarget:_globeNode];
    //constraint.gimbalLockEnabled = YES;
    _cameraNode.constraints = @[constraint];
    
    SCNSphere *sphere = [SCNSphere sphereWithRadius:30];
    sphere.firstMaterial.diffuse.contents = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.0];
    _cameraOrbit = [SCNNode nodeWithGeometry:sphere];
    _cameraOrbit.name = @"orbit";
    [_cameraOrbit addChildNode:_cameraNode];
    [_earthView.scene.rootNode addChildNode:_cameraOrbit];
}

- (void)addStarField
{
    SCNParticleSystem *stars = [SCNParticleSystem particleSystem];
    stars.particleImage = [UIImage imageNamed:@"star"];
    stars.particleSize = 0.1;
    stars.particleIntensity = 5.0;
    
    stars.birthRate = 500;
    stars.warmupDuration = 5;
    stars.birthLocation = SCNParticleBirthLocationSurface;
    stars.local = NO;
    stars.birthDirection = SCNParticleBirthDirectionConstant;
    stars.emittingDirection = SCNVector3Make(0, 0, 3);
    stars.emitterShape = [SCNSphere sphereWithRadius:100.0];
    stars.particleLifeSpan = 100000.0;
    stars.emissionDuration = 1;
    stars.emissionDurationVariation = 0.2;
    stars.loops = NO;
   
    [_earthView.scene.rootNode addParticleSystem:stars];
}

- (SCNNode *)addCube:(double)altitude lat:(double)lat lon:(double)lon size:(float)size color:(UIColor *)color
{
    // Create a cube and place it in the scene
    SCNBox *cube = [SCNBox boxWithWidth:size height:size length:size chamferRadius:0];
    cube.firstMaterial.diffuse.contents = color;
    SCNNode *cubeNode = [SCNNode nodeWithGeometry:cube];
    SCNVector3 position = [self spherical2cartesian:altitude lat:lat lon:lon];
    cubeNode.position = position;
    cubeNode.name = @"cube";
    return cubeNode;
}

- (SCNNode *)addPyramid:(double)altitude lat:(double)lat lon:(double)lon size:(float)size color:(UIColor *)color
{
    SCNPyramid *shape = [SCNPyramid pyramidWithWidth:size height:size length:size];
    shape.firstMaterial.diffuse.contents = color;
    SCNNode *shapeNode = [SCNNode nodeWithGeometry:shape];
    //[self setEulerAngles:shapeNode lat:lat lon:lon];

    SCNVector3 position = [self spherical2cartesian:altitude lat:lat lon:lon];
    shapeNode.position = position;
    
    shapeNode.name = @"pyramid";
    return shapeNode;
}

- (SCNNode *)addCapsule:(double)altitude lat:(double)lat lon:(double)lon color:(UIColor *)color
{
    SCNCapsule *cap = [SCNCapsule capsuleWithCapRadius:0.1 height:0.5];
    cap.firstMaterial.diffuse.contents = color;
    SCNNode *capNode = [SCNNode nodeWithGeometry:cap];
    SCNVector3 position = [self spherical2cartesian:altitude lat:lat lon:lon];
    capNode.position = position;
    capNode.name = @"capsule";
    return capNode;
}

- (SCNNode *)addSphere:(double)altitude lat:(double)lat lon:(double)lon radius:(double)radius color:(UIColor *)color
{
    SCNSphere *shape = [SCNSphere sphereWithRadius:radius];
    shape.firstMaterial.diffuse.contents = color;
    SCNNode *shapeNode = [SCNNode nodeWithGeometry:shape];
    SCNVector3 position = [self spherical2cartesian:altitude lat:lat lon:lon];
    shapeNode.position = position;
    shapeNode.name = @"sphere";
    return shapeNode;
}

- (SCNNode *)addTube:(double)altitude lat:(double)lat lon:(double)lon height:(double)height color:(UIColor *)color
{
    SCNTube *shape = [SCNTube tubeWithInnerRadius:0.1 outerRadius:0.11 height:height];
    shape.firstMaterial.diffuse.contents = color;
    SCNNode *shapeNode = [SCNNode nodeWithGeometry:shape];
    SCNVector3 position = [self spherical2cartesian:altitude lat:lat lon:lon];
    shapeNode.position = position;
    shapeNode.name = @"tube";
    return shapeNode;
}

- (void) drawSpaceJunk:(float)alt
    {
    SCNNode *yellowShape = nil;
    SCNNode *purpleShape = nil;
    SCNNode *orangeShape = nil;
    SCNNode *greenShape = nil;
    
    if (! _spaceJunkNode)
    {
        _spaceJunkNode = [SCNNode node];
        [_earthView.scene.rootNode addChildNode:_spaceJunkNode];
    }
    int k = 0;
    for (int i = 0; i < 180; i += 3) {
        for (int j = 0; j < 360; j += 3) {
            if (k % 4 == 0)
            {
                //;
                if (! yellowShape)
                {
                    yellowShape = [self addSphere:alt lat:(i <= 90 ? i : -(i - 90)) lon:(j <= 180 ? j : -(j - 180)) radius:0.1 color:[UIColor blueColor]];
                    [_spaceJunkNode addChildNode:yellowShape];
                }
                else
                {
                    SCNNode *clone = yellowShape.clone;
                    SCNVector3 position = [self spherical2cartesian:alt lat:(i <= 90 ? i : -(i - 90)) lon:(j <= 180 ? j : -(j - 180))];
                    clone.position = position;
                    [_spaceJunkNode addChildNode:clone];
                }
            }
            else if (k % 3 == 0)
            {
                if (! purpleShape)
                {
                    purpleShape = [self addCube:alt lat:(i <= 90 ? i : -(i - 90)) lon:(j <= 180 ? j : -(j - 180)) size:.1 color:[UIColor greenColor]];
                    [_spaceJunkNode addChildNode:purpleShape];
                }
                else
                {
                    SCNNode *clone = purpleShape.clone;
                    SCNVector3 position = [self spherical2cartesian:alt lat:(i <= 90 ? i : -(i - 90)) lon:(j <= 180 ? j : -(j - 180))];
                    clone.position = position;
                    [_spaceJunkNode addChildNode:clone];
                }
            }
            else if (k % 2 == 0)
            {
                if (! orangeShape)
                {
                    orangeShape = [self addCube:alt lat:(i <= 90 ? i : -(i - 90)) lon:(j <= 180 ? j : -(j - 180)) size:.1 color:[UIColor yellowColor]];
                    //orangeCube.opacity = 0.5;
                    [_spaceJunkNode addChildNode:orangeShape];
                }
                else
                {
                    SCNNode *clone = orangeShape.clone;
                    SCNVector3 position = [self spherical2cartesian:alt lat:(i <= 90 ? i : -(i - 90)) lon:(j <= 180 ? j : -(j - 180))];
                    clone.position = position;
                    [_spaceJunkNode addChildNode:clone];
                }
            }
            else
            {
                if (! greenShape)
                {
                    greenShape = [self addCube:alt lat:(i <= 90 ? i : -(i - 90)) lon:(j <= 180 ? j : -(j - 180)) size:.2 color:[UIColor redColor]];
                    [_spaceJunkNode addChildNode:greenShape];
                }
                else
                {
                    SCNNode *clone = greenShape.clone;
                    SCNVector3 position = [self spherical2cartesian:alt lat:(i <= 90 ? i : -(i - 90)) lon:(j <= 180 ? j : -(j - 180))];
                    clone.position = position;
                    [_spaceJunkNode addChildNode:clone];
                }
            }
            k++;
        }
    }
}

- (SCNVector3)spherical2cartesian:(double)altitude lat:(double)lat lon:(double)lon
{
    static const float radius = 5.7;
    
    float rho = altitude + radius;
    
    float theta = (lat >= 0 ? (90 - lat) * deg2rad : (90 + fabs(lat)) * deg2rad);
    float phi = (lon >= 0 ? lon * deg2rad : (180.0 + (180 - fabs(lon))) * deg2rad);
    
    float x = rho * sin(theta) * cos(phi);
    float y = rho * sin(theta) * sin(phi);
    float z = rho * cos(theta);  // z is 'up'

    return SCNVector3Make(y, z, x);  //convert to scenekit axises rotated -90 around x and -90 around y
}

- (void)initEarthview
{
    self.view.backgroundColor = [UIColor clearColor];

    _earthView = [[SCNView alloc] initWithFrame:self.view.bounds];
    _earthView.scene = [SCNScene scene];
    _earthView.autoenablesDefaultLighting = YES;
    _earthView.userInteractionEnabled = YES;
    _earthView.showsStatistics = YES;        // show statistics fps and timing information
    _earthView.backgroundColor = [UIColor clearColor];  // configure the view
    _earthView.antialiasingMode = SCNAntialiasingModeMultisampling2X;
    _earthView.autoresizingMask = UIViewAutoresizingFlexibleHeight |
                                      UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_earthView];
}

- (void)addSpaceJunk
{
    [self drawSpaceJunk:8];
    [self drawSpaceJunk:10];
    [self drawSpaceJunk:12];
    [self drawSpaceJunk:15];
    [self drawSpaceJunk:18];

    [_spaceJunkNode addChildNode:[self addPyramid:1 lat:0 lon:0 size:0.5 color:[UIColor redColor]]];
    [_spaceJunkNode addChildNode:[self addPyramid:1 lat:0 lon:90 size:0.5 color:[UIColor orangeColor]]];
    [_spaceJunkNode addChildNode:[self addPyramid:1 lat:0 lon:-90 size:0.5 color:[UIColor yellowColor]]];
    [_spaceJunkNode addChildNode:[self addPyramid:1 lat:90 lon:0 size:0.5 color:[UIColor blueColor]]];

    [_earthView.scene.rootNode addChildNode:self.spaceJunkNode];
}

-(void)setupGestureRecognizers
{
    _rotationGestureRecognizer = [[UIRotationGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(handleRotations:)];
    
    _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(handlePinches:)];
    _panGestureRecognizer = [[UIPanGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(handlePan:)];
    _panGestureRecognizer.minimumNumberOfTouches = 1;
    _panGestureRecognizer.maximumNumberOfTouches = 1;
    
    _tapGestureRecognizer = [[UITapGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(handleTap:)];
    _tapGestureRecognizer.numberOfTapsRequired = 2;
    _tapGestureRecognizer.numberOfTouchesRequired = 1;
    
    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc]
                                           initWithTarget:self action:@selector(handleLongPress:)];
    _longPressGestureRecognizer.allowableMovement = 22.0;
    _longPressGestureRecognizer.numberOfTouchesRequired = 3;
    _longPressGestureRecognizer.numberOfTapsRequired = 0;
    _longPressGestureRecognizer.minimumPressDuration = 0.1;
    
    NSMutableArray *gestureRecognizers = [NSMutableArray array];
    //[gestureRecognizers addObjectsFromArray:self.view.gestureRecognizers];
    [gestureRecognizers addObject:_rotationGestureRecognizer];
    [gestureRecognizers addObject:_pinchGestureRecognizer];
    [gestureRecognizers addObject:_panGestureRecognizer];
    [gestureRecognizers addObject:_tapGestureRecognizer];
    [gestureRecognizers addObject:_longPressGestureRecognizer];

    _earthView.gestureRecognizers = gestureRecognizers;
}

- (void)createEarthView:(bool)countries
{
    [self initEarthview];
    
    [self addStarField];
    [self addGlobe:96 rebuild:NO countries:countries];
    
    [self addCrossHair];
    [self addCamera];

    [self setupGestureRecognizers];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self createEarthView:true];
}

@end
    
