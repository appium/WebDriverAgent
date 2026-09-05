#import "FBCoordinateProbeViewController.h"

@interface FBCoordinateProbeCanvas : UIView
@property (nonatomic, copy) void (^onTouch)(NSString *phase, CGPoint point);
@end

@implementation FBCoordinateProbeCanvas

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  self.onTouch(@"began", [touches.anyObject locationInView:self]);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  self.onTouch(@"moved", [touches.anyObject locationInView:self]);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  self.onTouch(@"ended", [touches.anyObject locationInView:self]);
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  self.onTouch(@"cancelled", [touches.anyObject locationInView:self]);
}

- (void)drawRect:(CGRect)rect
{
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetStrokeColorWithColor(context, UIColor.whiteColor.CGColor);
  for (NSInteger i = 1; i < 4; i++) {
    CGFloat x = CGRectGetWidth(self.bounds) * i / 4.0;
    CGFloat y = CGRectGetHeight(self.bounds) * i / 4.0;
    CGContextMoveToPoint(context, x, 0);
    CGContextAddLineToPoint(context, x, CGRectGetHeight(self.bounds));
    CGContextMoveToPoint(context, 0, y);
    CGContextAddLineToPoint(context, CGRectGetWidth(self.bounds), y);
  }
  CGContextStrokePath(context);
}

@end

@interface FBCoordinateProbeViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) FBCoordinateProbeCanvas *canvas;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *measurement;
@property (nonatomic) NSUInteger touchCount;
@end

@implementation FBCoordinateProbeViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.title = @"Coordinate Probe";
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  self.measurement = [NSMutableDictionary dictionary];

  self.statusLabel = [UILabel new];
  self.statusLabel.accessibilityIdentifier = @"probe-status";
  self.statusLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
  self.statusLabel.numberOfLines = 0;
  [self.view addSubview:self.statusLabel];

  self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"Touch", @"Scroll"]];
  self.modeControl.accessibilityIdentifier = @"probe-mode";
  self.modeControl.selectedSegmentIndex = 0;
  [self.modeControl addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
  [self.view addSubview:self.modeControl];

  self.canvas = [FBCoordinateProbeCanvas new];
  self.canvas.backgroundColor = UIColor.systemBlueColor;
  self.canvas.isAccessibilityElement = YES;
  self.canvas.accessibilityIdentifier = @"coordinate-canvas";
  self.canvas.accessibilityLabel = @"Coordinate canvas";
  self.canvas.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
  self.canvas.contentMode = UIViewContentModeRedraw;
  __weak typeof(self) weakSelf = self;
  self.canvas.onTouch = ^(NSString *phase, CGPoint point) {
    FBCoordinateProbeViewController *controller = weakSelf;
    if (nil == controller) {
      return;
    }
    if ([phase isEqualToString:@"began"]) {
      controller.touchCount++;
      controller.measurement[@"start"] = @[@(point.x), @(point.y)];
    }
    controller.measurement[@"last"] = @[@(point.x), @(point.y)];
    controller.measurement[@"phase"] = phase;
    controller.measurement[@"count"] = @(controller.touchCount);
    [controller publishMeasurement];
  };
  [self.view addSubview:self.canvas];

  self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  self.table.accessibilityIdentifier = @"probe-table";
  self.table.rowHeight = 44;
  self.table.dataSource = self;
  self.table.delegate = self;
  self.table.hidden = YES;
  [self.view addSubview:self.table];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  // Use the app's actual available area, including navigation bars and resized iPad windows.
  CGRect safeFrame = self.view.safeAreaLayoutGuide.layoutFrame;
  CGFloat width = MAX(0, CGRectGetWidth(safeFrame) - 40);
  CGFloat left = CGRectGetMinX(safeFrame) + 20;
  CGFloat top = CGRectGetMinY(safeFrame) + 8;
  self.statusLabel.frame = CGRectMake(left, top, width, 96);
  self.modeControl.frame = CGRectMake(left, top + 104, width, 30);
  CGRect contentFrame = CGRectMake(left, top + 146, width,
                                   MAX(0, CGRectGetMaxY(safeFrame) - top - 166));
  self.canvas.frame = contentFrame;
  self.table.frame = contentFrame;
  [self publishMeasurement];
}

- (void)publishMeasurement
{
  UIWindow *window = self.view.window;
  if (nil == window) {
    return;
  }
  CGRect bounds = self.canvas.bounds;
  CGRect frame = [self.canvas convertRect:bounds toView:window];
  // Touch coordinates are local to the canvas. Window geometry lets tests compare
  // those measurements with WDA's element rectangles without assuming a screen size.
  self.measurement[@"canvasBounds"] = @[@(bounds.size.width), @(bounds.size.height)];
  self.measurement[@"canvasWindowRect"] = @[@(frame.origin.x), @(frame.origin.y),
                                           @(frame.size.width), @(frame.size.height)];
  self.measurement[@"windowSize"] = @[@(window.bounds.size.width), @(window.bounds.size.height)];
  self.measurement[@"screenSize"] = @[@(window.screen.bounds.size.width), @(window.screen.bounds.size.height)];
  self.measurement[@"scrollY"] = @(self.table.contentOffset.y);
  NSData *data = [NSJSONSerialization dataWithJSONObject:self.measurement
                                               options:NSJSONWritingSortedKeys
                                                 error:nil];
  self.statusLabel.text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)modeChanged
{
  self.canvas.hidden = self.modeControl.selectedSegmentIndex == 1;
  self.table.hidden = !self.canvas.hidden;
  [self publishMeasurement];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 80;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"probe-row"];
  if (nil == cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"probe-row"];
  }
  cell.textLabel.text = [NSString stringWithFormat:@"Probe row %ld", (long)indexPath.row];
  cell.accessibilityIdentifier = [NSString stringWithFormat:@"probe-row-%ld", (long)indexPath.row];
  return cell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  [self publishMeasurement];
}

@end
