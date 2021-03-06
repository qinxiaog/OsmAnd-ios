//
//  OADebugHudViewController.mm
//  OsmAnd
//
//  Created by Alexey Pelykh on 3/28/14.
//  Copyright (c) 2014 OsmAnd. All rights reserved.
//

#import "OADebugHudViewController.h"

#import "OAMapViewController.h"
#import "OAMapRendererView.h"
#import "OAAutoObserverProxy.h"
#import "OARootViewController.h"
#import "OADebugActionsViewController.h"
#import "OANavigationController.h"

#include <OsmAndCore/Utilities.h>

#define _(name) OADebugHudViewController__##name
#define commonInit _(commonInit)
#define deinit _(deinit)

@interface OADebugHudViewController () <UIPopoverControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *_overlayContainer;
@property (weak, nonatomic) IBOutlet UITextView *_stateTextview;
@property (weak, nonatomic) IBOutlet UITextView *_outputTextview;
@property (weak, nonatomic) IBOutlet UIButton *_debugActionsButton;
@property (weak, nonatomic) IBOutlet UIButton *_debugPinOverlayButton;
@property (weak, nonatomic) IBOutlet UILabel *_stateTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *_outputTitleLabel;

@end

@implementation OADebugHudViewController
{
    OAAutoObserverProxy* _rendererStateObserver;
    OAAutoObserverProxy* _rendererSettingsObserver;

    UIPopoverController* _lastMenuPopoverController;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    _rendererStateObserver = [[OAAutoObserverProxy alloc] initWith:self withHandler:@selector(onRendererStateChanged)];
    _rendererSettingsObserver = [[OAAutoObserverProxy alloc] initWith:self withHandler:@selector(onRendererSettingsChanged)];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self collectState];
    OAMapViewController* mapViewController = [OARootViewController instance].mapPanel.mapViewController;
    [_rendererStateObserver observe:mapViewController.stateObservable];
    [_rendererSettingsObserver observe:mapViewController.settingsObservable];

    [self._debugPinOverlayButton setImage:[UIImage imageNamed:
                                           self._overlayContainer.userInteractionEnabled
                                           ? @"HUD_debug_pin_filled_button.png"
                                           : @"HUD_debug_pin_button.png"]
                                 forState:UIControlStateNormal];
}

- (void)openMenu:(UIViewController*)menuViewController fromView:(UIView*)view
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
    {
        // For iPhone and iPod, push menu to navigation controller
        [self.navigationController pushViewController:menuViewController
                                             animated:YES];
    }
    else //if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        // For iPad, open menu in a popover with it's own navigation controller
        UINavigationController* popoverNavigationController = [[OANavigationController alloc] initWithRootViewController:menuViewController];
        _lastMenuPopoverController = [[UIPopoverController alloc] initWithContentViewController:popoverNavigationController];
        _lastMenuPopoverController.delegate = self;

        [_lastMenuPopoverController presentPopoverFromRect:view.frame
                                                    inView:self.view
                                  permittedArrowDirections:UIPopoverArrowDirectionLeft|UIPopoverArrowDirectionRight
                                                  animated:YES];
    }
}

- (IBAction)onDebugActionsButtonClicked:(id)sender
{
    [self openMenu:[[OADebugActionsViewController alloc] init]
          fromView:self._debugActionsButton];
}

- (IBAction)onDebugPinOverlayButtonClicked:(id)sender
{
    self._overlayContainer.userInteractionEnabled = !self._overlayContainer.userInteractionEnabled;
    [self._debugPinOverlayButton setImage:[UIImage imageNamed:
                                           self._overlayContainer.userInteractionEnabled
                                           ? @"HUD_debug_pin_filled_button.png"
                                           : @"HUD_debug_pin_button.png"]
                                 forState:UIControlStateNormal];
}

- (void)collectState
{
    OAMapViewController* mapVC = [OARootViewController instance].mapPanel.mapViewController;
    if (![mapVC isViewLoaded])
        return;

    OAMapRendererView* mapRendererView = (OAMapRendererView*)mapVC.view;

    NSMutableString* stateDump = [[NSMutableString alloc] init];

    [stateDump appendFormat:@"target31             : %d %d\n",
     mapRendererView.target31.x,
     mapRendererView.target31.y];
    [stateDump appendFormat:@"target (lon, lat)    : %f %f\n",
     OsmAnd::Utilities::get31LongitudeX(mapRendererView.target31.x),
     OsmAnd::Utilities::get31LatitudeY(mapRendererView.target31.y)];
    [stateDump appendFormat:@"zoom                 : %f\n", mapRendererView.zoom];
    [stateDump appendFormat:@"zoom level           : %d\n", static_cast<int>(mapRendererView.zoomLevel)];
    [stateDump appendFormat:@"azimuth              : %f\n", mapRendererView.azimuth];
    [stateDump appendFormat:@"elevation angle      : %f\n", mapRendererView.elevationAngle];
    [stateDump appendFormat:@"symbols              : %d\n", mapRendererView.symbolsCount];
    [stateDump appendFormat:@"symbols suspended    : %s\n", mapRendererView.isSymbolsUpdateSuspended ? "yes" : "no"];

    [self._stateTextview setText:stateDump];
}

- (void)onRendererStateChanged
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self collectState];
    });
}

- (void)onRendererSettingsChanged
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self collectState];
    });
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad &&
       _lastMenuPopoverController == popoverController)
    {
        _lastMenuPopoverController = nil;
    }
}

#pragma mark -

+ (OADebugHudViewController*)attachTo:(UIViewController*)hostController
{
    OADebugHudViewController* instance = [[OADebugHudViewController alloc] initWithNibName:@"DebugHUD"
                                                                                    bundle:nil];
    [hostController addChildViewController:instance];
    [instance.view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [hostController.view addSubview:instance.view];
    [hostController.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:@{@"view":instance.view}]];
    [hostController.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:@{@"view":instance.view}]];
    [hostController.view bringSubviewToFront:instance.view];
    
    return instance;
}

@end
