//
//  AddDeviceVC.m
//  SmartLightApp
//cf1d    7631
//  Created by stuart watts on 22/11/2017.
//  Copyright © 2017 Kalpesh Panchasara. All rights reserved.
//

#import "AddDeviceVC.h"
#import "HistoryCell.h"
#import "AuthenticationVC.h"
#import "DeviceDetailVC.h"
#import "BridgeVC.h"
#import "MNMPullToRefreshManager.h"

@interface AddDeviceVC ()<UITableViewDelegate,UITableViewDataSource,URLManagerDelegate,FCAlertViewDelegate,MNMPullToRefreshManagerClient,CBCentralManagerDelegate,UIGestureRecognizerDelegate>
{
    UILabel * lblSuccessMsg;
    UITableView * tblView;
    NSMutableArray * deviceListArray ;
    CBPeripheral * myPeripheral;
    BOOL isOneDvcAdded;
    BOOL isAssociated;
    NSString * newDeviceID;
    NSInteger groupCount;
    NSString * strTTL, * strSqence, * strDevId, * strDestID, * strCrc, * strAddress, * strOpCode;
    BOOL isAllowOnce, isSentForGroup;
    NSMutableArray * groupDeviceSelectedArr;
    
    NSInteger recieveCount, sentCount;
    NSString * strGroupTxt, * strDeviceNames, * strDeviceType;
    NSMutableDictionary * selectedDict;
    UIImageView * statusImg;

    BOOL isDeviceResponsed;
    NSString * strSelectedSingleDeviceAddres;
    NSString * strSentGroupHexID;
    NSMutableArray * syncedArray;
    MNMPullToRefreshManager * topPullToRefreshManager;
    BOOL isMovedforConnection;
    CBCentralManager*centralManager;
    
    int totalCounts;
    BOOL isViewDisappeared;
    NSTimer * saveTimoutTimer, * autoConnectionTimer, * retryConnectTimer;
    
    int spinCount;
    NSTimer * spinTimer;
    UILabel * lblDeviceFound;
    int connectionTrialCount, lastConnectTryCount;
    NSString * strDeviceMenuData , * strConnectedDeviceName;
}
@end

@implementation AddDeviceVC
@synthesize isForGroup,isfromEdit,detailDict;

- (void)viewDidLoad
{
    
    connectionTrialCount = 0;
    
    [topPullToRefreshManager setPullToRefreshViewVisible:NO];

    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

    UIImageView * imgBack = [[UIImageView alloc] init];
    imgBack.frame = CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT);
    imgBack.image = [UIImage imageNamed:[[NSUserDefaults standardUserDefaults]valueForKey:@"globalBackGroundImage"]];
    [self.view addSubview:imgBack];

    [super viewDidLoad];
    
    deviceListArray = [[NSMutableArray alloc] init];
    groupDeviceSelectedArr = [[NSMutableArray alloc] init];
    selectedDict = [[NSMutableDictionary alloc] init];
    
    NSString * strQuery = [NSString stringWithFormat:@"Select * from Device_Table where user_id ='%@' and status = '1' group by ble_address",CURRENT_USER_ID];
    [[DataBaseManager dataBaseManager] execute:strQuery resultsArray:deviceListArray];
    
    isOneDvcAdded = NO;
    isAssociated = NO;
    isSentForGroup = NO;
    
        if([deviceListArray count]>0)
        {
            isOneDvcAdded = YES;
            [deviceListArray setValue:@"No" forKey:@"isSelected"];
        }
        else
        {
//            if ([[[BLEManager sharedManager] getLastConnected] count]>0)
//            {
//                isOneDvcAdded =YES;
//            }
//            else
//            {
//                isOneDvcAdded = NO;
//            }
        }
    
    [self setNavigationViewFrames];
    [self setMessageViewContent];
    [topPullToRefreshManager tableViewReloadFinishedAnimated:NO];

    
    
    // Do any additional setup after loading the view.
}

-(void)viewWillAppear:(BOOL)animated
{
    isScanningSocket = NO;

    if (@available(iOS 10.0, *)) {
        if (centralManager.state == CBCentralManagerStatePoweredOn || centralManager.state == CBManagerStateUnknown)
        {
        }
        else
        {
            [self GlobalBLuetoothCheck];
        }
    } else
    {
        if (centralManager.state == CBCentralManagerStatePoweredOff)
        {
            [self GlobalBLuetoothCheck];
        }
        // Fallback on earlier versions
    }
    
    [topPullToRefreshManager setPullToRefreshViewVisible:YES];

    currentScreen = @"AddDevice";

    [APP_DELEGATE hideTabBar:self.tabBarController];
    [APP_DELEGATE isNetworkreachable];
    
    isNonConnectScanning = YES;
    
//    if (isMovedforConnection)
//    {
//         [self refreshBtnClick];
//    }
//    else
    [[BLEManager sharedManager] disconnectDevice:globalPeripheral];
    NSArray * tmpArr = [[BLEManager sharedManager]getLastConnected];
    [[BLEManager sharedManager] stopScan];
    [[[BLEManager sharedManager] foundDevices] removeAllObjects];
    for (int i=0; i<tmpArr.count; i++)
    {
        CBPeripheral * p = [tmpArr objectAtIndex:i];
        [[BLEManager sharedManager]disconnectDevice:p];
    }

        [self InitialBLE];
        
        [[[BLEManager sharedManager] nonConnectArr] removeAllObjects];
        [[BLEManager sharedManager] rescan];

    [[NSNotificationCenter defaultCenter] postNotificationName:kCheckButtonVisibilityNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"showBridgeScreen" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showBridgeScreen) name:@"showBridgeScreen" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:currentScreen object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBleStatus) name:currentScreen object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UpdateTableAddDevice" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(UpdateTableAddDevice) name:@"UpdateTableAddDevice" object:nil];

    [super viewWillAppear:YES];
    
    lastConnectTryCount = 0;
    [autoConnectionTimer invalidate];
    autoConnectionTimer = nil;
    autoConnectionTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(autoConnectCheck) userInfo:nil repeats:YES];
    [self autoConnectCheck];
    
    [APP_DELEGATE endHudProcess];
    [APP_DELEGATE startHudProcess:@"Looking for devices..."];
    [self performSelector:@selector(HideIndicatorTimeout) withObject:nil afterDelay:9];
}
-(void)HideIndicatorTimeout
{
    [APP_DELEGATE endHudProcess];
}
-(void)autoConnectCheck
{
    NSLog(@"==++++++++++++++++++++++++++++++++++++++%@",globalPeripheral);
    if (globalPeripheral.state == CBPeripheralStateConnected)
    {
    }
    else
    {
        if (isViewDisappeared == NO)
        {
            if ([[BLEManager sharedManager] autoConnectArr] > 0)
            {
                if (lastConnectTryCount >= [[[BLEManager sharedManager] autoConnectArr] count])
                {
                    lastConnectTryCount = 0;
                }
                if ([[[BLEManager sharedManager] autoConnectArr] count] > lastConnectTryCount)
                {
                    CBPeripheral * p = [[[BLEManager sharedManager] autoConnectArr] objectAtIndex:lastConnectTryCount];
                    if (p.state == CBPeripheralStateDisconnected)
                    {
                        [[BLEManager sharedManager] connectDevice:p];
                    }
                    lastConnectTryCount = lastConnectTryCount + 1;
                }
            }
        }
    }
}
-(void)viewWillDisappear:(BOOL)animated
{
    [retryConnectTimer invalidate];
    retryConnectTimer = nil;
    
    isViewDisappeared = YES;
    
       [autoConnectionTimer invalidate];
       autoConnectionTimer = nil;
       

       [saveTimoutTimer invalidate];
       saveTimoutTimer = nil;
    if (globalPeripheral.state == CBPeripheralStateConnected)
    {
        [[BLEManager sharedManager] disconnectDevice:globalPeripheral];
    }
}
-(void)viewDidDisappear:(BOOL)animated
{
    isNonConnectScanning = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"CallNotificationforNonConnectforAdd" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"showBridgeScreen" object:nil];
}

#pragma mark - Set Frames
-(void)setNavigationViewFrames
{
    UIView * viewHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, 64)];
    [viewHeader setBackgroundColor:[UIColor clearColor]];
    [self.view addSubview:viewHeader];
    
    UILabel * lblBack = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, 64)];
    lblBack.backgroundColor = [UIColor blackColor];
    lblBack.alpha = 0.4;
    [viewHeader addSubview:lblBack];

    UILabel * lblTitle = [[UILabel alloc] initWithFrame:CGRectMake(50, 20, DEVICE_WIDTH-100, 44)];
    [lblTitle setBackgroundColor:[UIColor clearColor]];
    [lblTitle setText:@"Add device"];
    [lblTitle setTextAlignment:NSTextAlignmentCenter];
    [lblTitle setFont:[UIFont fontWithName:CGRegular size:textSizes+2]];
    [lblTitle setTextColor:[UIColor whiteColor]];
    [viewHeader addSubview:lblTitle];
    
    UIImageView * backImg = [[UIImageView alloc] initWithFrame:CGRectMake(10, 12+20, 12, 20)];
    [backImg setImage:[UIImage imageNamed:@"back_icon.png"]];
    [backImg setContentMode:UIViewContentModeScaleAspectFit];
    backImg.backgroundColor = [UIColor clearColor];
    [viewHeader addSubview:backImg];
    
    UIButton * btnBack = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnBack addTarget:self action:@selector(btnBackClick) forControlEvents:UIControlEventTouchUpInside];
    btnBack.frame = CGRectMake(0, 0, 70, 64);
    btnBack.backgroundColor = [UIColor clearColor];
    [viewHeader addSubview:btnBack];
    
    UIImageView * imgRefresh = [[UIImageView alloc] initWithFrame:CGRectMake(DEVICE_WIDTH-30, 20+13, 18, 18)];
    [imgRefresh setImage:[UIImage imageNamed:@"refresh_icon.png"]];
    [imgRefresh setContentMode:UIViewContentModeScaleAspectFit];
    imgRefresh.backgroundColor = [UIColor clearColor];
    [viewHeader addSubview:imgRefresh];
    
    UIButton * refreshBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [refreshBtn addTarget:self action:@selector(refreshBtnClick) forControlEvents:UIControlEventTouchUpInside];
    refreshBtn.frame = CGRectMake(DEVICE_WIDTH-60, 0, 60, 64);
    refreshBtn.backgroundColor = [UIColor clearColor];
    [viewHeader addSubview:refreshBtn];
    
    if (IS_IPHONE_X)
    {
        viewHeader.frame = CGRectMake(0, 0, DEVICE_WIDTH, 88);
        lblTitle.frame = CGRectMake(50, 40, DEVICE_WIDTH-100, 44);
        backImg.frame = CGRectMake(10, 12+44, 12, 20);
        btnBack.frame = CGRectMake(0, 0, 70, 88);
        lblBack.frame = CGRectMake(0, 0, DEVICE_WIDTH, 88);
        imgRefresh.frame = CGRectMake(DEVICE_WIDTH-30, 44 + 13, 18, 18);
        refreshBtn.frame = CGRectMake(DEVICE_WIDTH-60, 0, 60, 88);
    }
}

-(void)setMessageViewContent
{
    lblSuccessMsg = [[UILabel alloc] initWithFrame:CGRectMake(10, (DEVICE_HEIGHT-100)/2 + 64, DEVICE_WIDTH-20, 100)];
    [lblSuccessMsg setTextColor:[UIColor whiteColor]];
    [lblSuccessMsg setFont:[UIFont fontWithName:CGRegular size:textSizes+5]];
    [lblSuccessMsg setTextAlignment:NSTextAlignmentCenter];
    [lblSuccessMsg setNumberOfLines:3];
    [lblSuccessMsg setText:@"Searching  devices..."];
    lblSuccessMsg.hidden = YES;
    [self.view addSubview:lblSuccessMsg];
    
    tblView = [[UITableView alloc] initWithFrame:CGRectMake(0, 64, DEVICE_WIDTH, DEVICE_HEIGHT-64) style:UITableViewStylePlain];
    tblView.delegate = self;
    tblView.dataSource = self;
    tblView.backgroundColor = [UIColor clearColor];
    tblView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tblView.separatorColor = [UIColor darkGrayColor];
    [self.view addSubview:tblView];
    
    UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    longPressRecognizer.minimumPressDuration = 2.0;
    longPressRecognizer.delegate = self;
    [tblView addGestureRecognizer:longPressRecognizer];
    if (IS_IPHONE_X)
    {
        tblView.frame = CGRectMake(0, 88, DEVICE_WIDTH, DEVICE_HEIGHT-88-50);
    }
    if ([[[BLEManager sharedManager] nonConnectArr] count]==0)
    {
        [lblSuccessMsg setText:@"No devices found"];
        lblSuccessMsg.hidden = NO;
    }
    
    topPullToRefreshManager = [[MNMPullToRefreshManager alloc] initWithPullToRefreshViewHeight:60.0f tableView:tblView withClient:self];
    [topPullToRefreshManager setPullToRefreshViewVisible:YES];
    [topPullToRefreshManager tableViewReloadFinishedAnimated:YES];
}

#pragma mark - Button Click
-(void)btnBackClick
{
    isViewDisappeared = YES;
    [autoConnectionTimer invalidate];
    autoConnectionTimer = nil;
    
    [retryConnectTimer invalidate];
    retryConnectTimer = nil;

    [saveTimoutTimer invalidate];
    saveTimoutTimer = nil;

    if (globalPeripheral.state == CBPeripheralStateConnected)
    {
        [[BLEManager sharedManager] disconnectDevice:globalPeripheral];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UpdateTableAddDevice" object:nil];

    [self.navigationController popViewControllerAnimated:YES];
}
-(void)refreshBtnClick
{
    totalCounts = 0;
    isAssociated = NO;
    isNonConnectScanning = YES;
//    [APP_DELEGATE showScannerView:@"Searching for devices..."];
    [[[BLEManager sharedManager] nonConnectArr] removeAllObjects];
    [tblView reloadData];
    [[BLEManager sharedManager] rescan];
    
    [self performSelector:@selector(stopIndicator) withObject:nil afterDelay:5];
    [tblView reloadData];
}
//-(void)closeScaningftotalCounts
//{
//    NSArray * lastConnec = [[BLEManager sharedManager] getLastConnected];
//    if ([lastConnec count]==0)
//    {
//        [[[BLEManager sharedManager] nonConnectArr] removeAllObjects];
//    }
//    for (int i=0; i<[lastConnec count]; i++)
//    {
//        CBPeripheral * CBPD = [lastConnec objectAtIndex:i];
//        NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
//        [dict setObject:@"NA" forKey:@"Manufac"];
//        [dict setObject:CBPD forKey:@"peripheral"];
//        
//        if ([[[BLEManager sharedManager] nonConnectArr] count]==0)
//        {
//            [[[BLEManager sharedManager] nonConnectArr] addObject:dict];
//        }
//        else
//        {
//            if ([[[BLEManager sharedManager] nonConnectArr] containsObject:CBPD])
//            {
//                [[[BLEManager sharedManager] nonConnectArr] addObject:dict];
//            }
//        }
//    }
//    
//    [APP_DELEGATE hideScannerView];
//    [APP_DELEGATE endHudProcess];
//}
-(void)stopIndicator
{
    if ([[BLEManager sharedManager] nonConnectArr]>0)
    {
        [APP_DELEGATE hideScannerView];
        [APP_DELEGATE endHudProcess];
    }
    else
    {
        [APP_DELEGATE hideScannerView];
        [APP_DELEGATE endHudProcess];
        
        [alert removeFromSuperview];
        alert = [[FCAlertView alloc] init];
        alert.colorScheme = [UIColor blackColor];
        [alert makeAlertTypeCaution];
        [alert showAlertInView:self
                     withTitle:@"Smart Light"
                  withSubtitle:@"No devices found. Please try again later."
               withCustomImage:[UIImage imageNamed:@"logo.png"]
           withDoneButtonTitle:nil
                    andButtons:nil];
    }
}
#pragma mark - DEVICES METHODS
-(void)UpdateTableAddDevice
{
    [self refreshBtnClick];
}
-(void)AssociateSingleDevice:(NSString *)stringss withDeviceName:(NSString *)deviceName
{
    if ([stringss length]>=38)
    {
                NSString * kpstr = stringss;
                kpstr = [kpstr stringByReplacingOccurrencesOfString:@" " withString:@""];
                kpstr = [kpstr stringByReplacingOccurrencesOfString:@">" withString:@""];
                kpstr = [kpstr stringByReplacingOccurrencesOfString:@"<" withString:@""];

                NSRange range1 = NSMakeRange(0, 2);
                strTTL = [kpstr substringWithRange:range1];
                NSInteger int1 = [@"100" integerValue];
                NSData * dataTTL = [[NSData alloc] initWithBytes:&int1 length:1];
                
                NSRange range2 = NSMakeRange(2, 4);
                strSqence = [kpstr substringWithRange:range2];
                globalCount = globalCount + 1;
                NSInteger int2 = globalCount;
                NSData * dataSequence = [[NSData alloc] initWithBytes:&int2 length:2];
                
                NSRange range3 = NSMakeRange(6, 4);
                strDevId = [kpstr substringWithRange:range3];
                NSInteger int3 = [@"0000" integerValue];
                NSData * dataSelfDeviceID = [[NSData alloc] initWithBytes:&int3 length:2];
                
                NSInteger int4 = [@"0000" integerValue];
                NSData * dataDeviceID = [[NSData alloc] initWithBytes:&int4 length:2];
                
                NSInteger int5 = [@"0000" integerValue];
                NSData * dataCRC = [[NSData alloc] initWithBytes:&int5 length:2];
                
                NSRange range6 = NSMakeRange(18, 4);
                strOpCode = [kpstr substringWithRange:range6];
                NSInteger int6 = [@"49" integerValue];
                NSData * dataOpcode = [[NSData alloc] initWithBytes:&int6 length:2];
                
                if ([stringss length]>=38)
                {
                    NSRange range71 = NSMakeRange(34, 4);
                    NSString * strType = [kpstr substringWithRange:range71];
                    
                    [self getDeviceTypes:strType];
                }
        
                //Count Checksum
                NSMutableData * checkData = [[NSMutableData alloc] init];
                [checkData appendData:dataSequence];
                [checkData appendData:dataSelfDeviceID];
                [checkData appendData:dataDeviceID];
                [checkData appendData:dataCRC];//CRC as 0
                [checkData appendData:dataOpcode];
                
                NSString * keyfirst = [[NSUserDefaults standardUserDefaults] valueForKey:@"passKey"];
                NSData * encryptKeyData= [[NSData alloc] init];
                if ([keyfirst length]>30)
                {
                    NSRange rangeFirst = NSMakeRange(0, 16);
                    NSString * strVithCheck = [keyfirst substringWithRange:rangeFirst];
                    encryptKeyData = [self getUserKeyconverted:strVithCheck];
                }
                [checkData appendData:encryptKeyData];
                
                NSData * checksumData = [APP_DELEGATE GetCountedCheckSumData:checkData];

                NSMutableData * completeData = [[NSMutableData alloc] init];
                completeData = [dataTTL mutableCopy];
                [completeData appendData:dataSequence];
                [completeData appendData:dataSelfDeviceID];
                [completeData appendData:dataDeviceID];
                [completeData appendData:checksumData];
                [completeData appendData:dataOpcode];
                [completeData appendData:encryptKeyData];
                
        NSString * StrData = [NSString stringWithFormat:@"%@",completeData.debugDescription];
        StrData = [StrData stringByReplacingOccurrencesOfString:@" " withString:@""];
                StrData = [StrData stringByReplacingOccurrencesOfString:@"<" withString:@""];
                StrData = [StrData stringByReplacingOccurrencesOfString:@">" withString:@""];
                
                strRequetAddress = strAddress;
                for (int i=0; i<32-[strRequetAddress length]; i++)
                {
                    strRequetAddress = [strRequetAddress stringByAppendingString:@"00"];
                }
                
                NSString * strEncryptedKey = [APP_DELEGATE getStringConvertedinUnsigned:[[NSUserDefaults standardUserDefaults] valueForKey:@"passKey"]];
                NSString * strFinalData = [APP_DELEGATE getStringConvertedinUnsigned:StrData];
                
                NSData * requestData = [APP_DELEGATE SendAssociationRequestFirst:strFinalData withKey:strEncryptedKey withBLEAddress:[APP_DELEGATE getStringConvertedinUnsigned:strRequetAddress] withRawDataLength:completeData.length];

                [[BLEService sharedInstance] writeValuetoDeviceMsg:requestData with:globalPeripheral];
                [[NSUserDefaults standardUserDefaults] setInteger:globalCount forKey:@"GlobalCount"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                strAddress =  [strAddress uppercaseString];
                strDeviceNames  = deviceName;
                
                [self sendSecondPartofKey:kpstr];
            }
    else
    {
        [APP_DELEGATE hideScannerView];
        [APP_DELEGATE endHudProcess];
        
        [alert removeFromSuperview];
        alert = [[FCAlertView alloc] init];
        alert.colorScheme = [UIColor blackColor];
        [alert makeAlertTypeCaution];
        [alert showAlertInView:self
                     withTitle:@"Smart Light"
                  withSubtitle:@"Something went wrong. Please try again later."
               withCustomImage:[UIImage imageNamed:@"logo.png"]
           withDoneButtonTitle:nil
                    andButtons:nil];
    }
    
}
-(void)sendSecondPartofKey:(NSString *)kpstr
{
    NSRange range1 = NSMakeRange(0, 2);
    strTTL = [kpstr substringWithRange:range1];
    NSInteger int1 = [@"100" integerValue];
    NSData * data1 = [[NSData alloc] initWithBytes:&int1 length:1];
    
    globalCount = globalCount + 1;
    NSInteger int2 = globalCount;
//    NSInteger int2 = [@"1433" integerValue];

    NSData * data2 = [[NSData alloc] initWithBytes:&int2 length:2];
    
    NSInteger int3 = [@"0000" integerValue];
    NSData * data3 = [[NSData alloc] initWithBytes:&int3 length:2];
    
    int randomID = arc4random() % 9000 + 1000;
    NSInteger int8 = randomID;
    NSLog(@"=====>>>>>SENT RANDOM ID=====>>>>%d",randomID);
    
    NSData * data4 = [[NSData alloc] initWithBytes:&int8 length:2];
    newDeviceID = [NSString stringWithFormat:@"%ld",(long)int8];
    isAssociated = YES;
    
    NSInteger int6 = [@"50" integerValue];
    NSData * data6 = [[NSData alloc] initWithBytes:&int6 length:2];
    
    NSMutableData * checkData = [[NSMutableData alloc] init];
    [checkData appendData:data2];
    [checkData appendData:data3];
    [checkData appendData:data4];
    [checkData appendData:data3];
    [checkData appendData:data6];
    
    NSString * keyfirst = [[NSUserDefaults standardUserDefaults] valueForKey:@"passKey"];
    NSData * encryptKeyData= [[NSData alloc] init];
    if ([keyfirst length]>30)
    {
        NSRange rangeFirst = NSMakeRange(16, 16);
        NSString * strVithCheck = [keyfirst substringWithRange:rangeFirst];
        encryptKeyData = [self getUserKeyconverted:strVithCheck];
    }
    [checkData appendData:encryptKeyData];


    NSData * checksumData = [APP_DELEGATE GetCountedCheckSumData:checkData];
    
    NSMutableData * completeData = [[NSMutableData alloc] init];
    completeData = [data1 mutableCopy];
    [completeData appendData:data2];
    [completeData appendData:data3];
    [completeData appendData:data4];
    [completeData appendData:checksumData];
    [completeData appendData:data6];
    [completeData appendData:encryptKeyData];

    NSString * StrData = [NSString stringWithFormat:@"%@",completeData.debugDescription];
    StrData = [StrData stringByReplacingOccurrencesOfString:@" " withString:@""];
    StrData = [StrData stringByReplacingOccurrencesOfString:@"<" withString:@""];
    StrData = [StrData stringByReplacingOccurrencesOfString:@">" withString:@""];
    
    for (int i=0; i<40-[StrData length]; i++)
    {
        StrData = [StrData stringByAppendingString:@"00"];
    }
    
    NSString * strEncryptedKey = [APP_DELEGATE getStringConvertedinUnsigned:[[NSUserDefaults standardUserDefaults] valueForKey:@"passKey"]];
    NSString * strFinalData = [APP_DELEGATE getStringConvertedinUnsigned:StrData];
    NSData * requestData = [APP_DELEGATE SendAssociationRequestSecond:strFinalData withKey:strEncryptedKey withBLEAddress:[APP_DELEGATE getStringConvertedinUnsigned:strAddress] withDataLength:completeData.length];
    
    for (int i=0; i<32-[strRequetAddress length]; i++)
    {
        strRequetAddress = [strRequetAddress stringByAppendingString:@"00"];
    }
    [[BLEService sharedInstance] writeValuetoDeviceMsg:requestData with:globalPeripheral];
    [[NSUserDefaults standardUserDefaults] setInteger:globalCount forKey:@"GlobalCount"];
    [[NSUserDefaults standardUserDefaults] synchronize];


}
-(NSData *)GetChecksumfromString:(NSData *)checksData
{
    NSUInteger len = [checksData length];
    Byte *byteData = (Byte*)malloc(len);
    memcpy(byteData, [checksData bytes], len);
    
    int16 checksum = '\0';
    for (int i = 0; i < len; i++)
    {
        checksum += byteData[i];
    }
    NSData * checkSumData = [[NSData alloc] initWithBytes:&checksum length:2];
    return checkSumData;
}
-(void)TimeOutForDeviceSave
{
    [APP_DELEGATE hideScannerView];
    [APP_DELEGATE endHudProcess];

    if (isDeviceResponsed)
    {
    }
    else
    {
        isAllowOnce = NO;
        tblView.hidden = NO;

        if (isViewDisappeared)
        {
            
        }
        else
        {
            [alert removeFromSuperview];
            alert = [[FCAlertView alloc] init];
            alert.colorScheme = [UIColor blackColor];
            [alert makeAlertTypeCaution];
            alert.tag = 125;
//            [alert showAlertInView:self
//                         withTitle:@"Smart Light"
//                      withSubtitle:@"Something went wrong. Please try again."
//                   withCustomImage:[UIImage imageNamed:@"logo.png"]
//               withDoneButtonTitle:nil
//                        andButtons:nil];
        }
        
    }
}
-(void)ResetDeviceIfnotAddedCorrectly
{
    [APP_DELEGATE sendSignalViaScan:@"Delete" withDeviceID:newDeviceID withValue:@"0"]; //KalpeshScanCode
    if (globalPeripheral.state == CBPeripheralStateConnected)
    {
        NSInteger int1 = [@"100" integerValue];
        NSData * data1 = [[NSData alloc] initWithBytes:&int1 length:1];
        
        NSMutableData * collectChekData = [[NSMutableData alloc] init];
        globalCount = globalCount + 1;
        
        NSInteger int2 = globalCount;
        NSData * data2 = [[NSData alloc] initWithBytes:&int2 length:2];
        collectChekData = [data2 mutableCopy];
        
        NSInteger int3 = [@"9000" integerValue];
        NSData * data3 = [[NSData alloc] initWithBytes:&int3 length:2];
        [collectChekData  appendData:data3];
        
        NSInteger int4 = [newDeviceID integerValue];
        NSData * data4 = [[NSData alloc] initWithBytes:&int4 length:2];
        [collectChekData  appendData:data4];
        
        NSInteger int5 = [@"0" integerValue];
        NSData * data5 = [[NSData alloc] initWithBytes:&int5 length:2];
        [collectChekData  appendData:data5];
        
        NSInteger int6 = [@"55" integerValue];
        NSData * data6 = [[NSData alloc] initWithBytes:&int6 length:2];
        [collectChekData  appendData:data6];
        
        NSData * finalCheckData = [APP_DELEGATE GetCountedCheckSumData:collectChekData];
        
        NSMutableData * completeData = [[NSMutableData alloc] init];
        completeData = [data1 mutableCopy];
        [completeData appendData:data2];
        [completeData appendData:data3];
        [completeData appendData:data4];
        [completeData appendData:finalCheckData];
        [completeData appendData:data6];
        
        NSString * StrData = [NSString stringWithFormat:@"%@",completeData.debugDescription];
        StrData = [StrData stringByReplacingOccurrencesOfString:@" " withString:@""];
        StrData = [StrData stringByReplacingOccurrencesOfString:@"<" withString:@""];
        StrData = [StrData stringByReplacingOccurrencesOfString:@">" withString:@""];
        
        NSString * strEncryptedKey = [APP_DELEGATE getStringConvertedinUnsigned:[[NSUserDefaults standardUserDefaults] valueForKey:@"passKey"]];
        NSString * strFinalData = [APP_DELEGATE getStringConvertedinUnsigned:StrData];
        
        NSData * requestData = [APP_DELEGATE GetEncryptedKeyforData:strFinalData withKey:strEncryptedKey withLength:completeData.length];
        [[BLEService sharedInstance] writeValuetoDeviceMsg:requestData with:globalPeripheral];
        [[NSUserDefaults standardUserDefaults] setInteger:globalCount forKey:@"GlobalCount"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
#pragma mark- UITableView Methods
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;   // custom view for header. will be adjusted to default or specified header height
{
    UIView * headerView =[[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, 45)];
    headerView.backgroundColor = [UIColor blackColor];
    
    UILabel *lblmenu=[[UILabel alloc]init];
    lblmenu.text = @" Tap on Add button to add device.";
    [lblmenu setTextColor:[UIColor whiteColor]];
    [lblmenu setFont:[UIFont fontWithName:CGRegular size:textSizes-1]];
    lblmenu.frame = CGRectMake(5, 0, DEVICE_WIDTH, 45);
    [headerView addSubview:lblmenu];
    
    return headerView;
}
-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 45;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[BLEManager sharedManager] nonConnectArr] count];
//    return 20;
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 70;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    HistoryCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ReuseActivityCell"];
    if (cell==nil)
    {
        cell = [[HistoryCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ReuseActivityCell"];
    }
    
    cell.lblConnect.text = @"Add";
    cell.lblAddress.hidden = NO;
    cell.lblAddress.text = @"NA";
    cell.imgIcon.hidden = NO;
    
    cell.lblDeviceName.font = [UIFont fontWithName:CGRegular size:textSizes+2];
    cell.lblAddress.font = [UIFont fontWithName:CGRegular size:textSizes-1];
    cell.lblConnect.font = [UIFont fontWithName:CGRegular size:textSizes-1];
    
    cell.lblConnect.frame = CGRectMake(DEVICE_WIDTH-60, 0, DEVICE_WIDTH-60, 60);
    
    NSMutableArray * arrayDevices = [[NSMutableArray alloc] init];
    arrayDevices =[[BLEManager sharedManager] nonConnectArr];
    
    if ([arrayDevices count]>0)
    {
        CBPeripheral * p = [[arrayDevices objectAtIndex:indexPath.row] objectForKey:@"peripheral"];
        if (p.state == CBPeripheralStateConnected)
        {
            cell.lblConnect.text = @"Add";
        }
        else
        {
            cell.lblConnect.text = @"Add";
        }
        
        if ([[[arrayDevices objectAtIndex:indexPath.row] objectForKey:@"isAdded"] isEqualToString:@"1"])
        {
            cell.lblAddress.textColor = [UIColor colorWithRed:18/255.0f green:188.0/255.0f blue:0 alpha:1];
        }
        else
        {
            cell.lblAddress.textColor = [UIColor whiteColor];
        }
        

        
        NSString * manuStr = [[arrayDevices objectAtIndex:indexPath.row] objectForKey:@"Manufac"];
//        NSRange rangeFirst = NSMakeRange(1, 4);
//        NSString * strOpCodeCheck = [manuStr substringWithRange:rangeFirst];

        {
            NSString * kpstr = manuStr;

            
            kpstr = [kpstr stringByReplacingOccurrencesOfString:@" " withString:@""];
            kpstr = [kpstr stringByReplacingOccurrencesOfString:@">" withString:@""];
            kpstr = [kpstr stringByReplacingOccurrencesOfString:@"<" withString:@""];

            if ([kpstr length]>=38)
            {
                NSRange range71 = NSMakeRange(22, 12);
                NSString * str1 = [kpstr substringWithRange:range71];
                cell.lblAddress.text = [str1 uppercaseString];
                
                range71 = NSMakeRange([kpstr length]-4, 4);
                NSString * strType = [kpstr substringWithRange:range71];
                
                if ([strType isEqualToString:@"0100"])
                {
                    cell.lblDeviceName.text = @"Vithamas Light";
                    cell.imgIcon.image = [UIImage imageNamed:@"default_pic.png"];
                }
                else if ([strType isEqualToString:@"0200"])
                {
                    cell.lblDeviceName.text = @"Vithamas White Light";
                    cell.imgIcon.image = [UIImage imageNamed:@"default_pic.png"];
                }
                else if ([strType isEqualToString:@"0300"])
                {
                    cell.lblDeviceName.text = @"Vithamas Switch";
                    cell.imgIcon.image = [UIImage imageNamed:@"default_switch_icon.png"];
                }
                else if ([strType isEqualToString:@"0400"])
                {
                    cell.lblDeviceName.text = @"Vithamas Socket";
                    cell.imgIcon.image = [UIImage imageNamed:@"default_socket_icon.png"];
                }
                else if ([strType isEqualToString:@"0500"])
                {
                    cell.lblDeviceName.text = @"Vithamas Fan";
                    cell.imgIcon.image = [UIImage imageNamed:@"default_fan_icon.png"];
                }
                else if ([strType isEqualToString:@"0600"])
                {
                    cell.lblDeviceName.text = @"Vithamas Strip Light";
                    cell.imgIcon.image = [UIImage imageNamed:@"stripwhite.png"];//stripwhite
                }
                else if ([strType isEqualToString:@"0700"])
                {
                    cell.lblDeviceName.text = @"Vithamas Night lamp";
                    cell.imgIcon.image = [UIImage imageNamed:@"default_lamp.png"];
                }
                else if ([strType isEqualToString:@"0800"])
                {
                    cell.lblDeviceName.text = @"Vithamas Power socket strip";
                    cell.imgIcon.image = [UIImage imageNamed:@"default_powerstrip_icon.png"];
                }
            }
        }
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    return cell;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
{
    [APP_DELEGATE startHudProcess:@"Saving Device..."];
    
//    [self performSelector:@selector(TimeOutForDeviceSave) withObject:nil afterDelay:14];
    
    NSMutableArray * arrayDevices = [[NSMutableArray alloc] init];
    arrayDevices =[[BLEManager sharedManager] nonConnectArr];
    
    if ([arrayDevices count]>0)
    {
        CBPeripheral * p = [[arrayDevices objectAtIndex:indexPath.row] objectForKey:@"peripheral"];
        myPeripheral = p;
        NSString * manuStr = [[arrayDevices objectAtIndex:indexPath.row] objectForKey:@"Manufac"];
        manuStr = [manuStr stringByReplacingOccurrencesOfString:@" " withString:@""];
        manuStr = [manuStr stringByReplacingOccurrencesOfString:@">" withString:@""];
        manuStr = [manuStr stringByReplacingOccurrencesOfString:@"<" withString:@""];
        
        HistoryCell *cell = (HistoryCell *)[tableView cellForRowAtIndexPath:indexPath];
        strSelectedSingleDeviceAddres = [[NSString stringWithFormat:@"%@",cell.lblAddress.text] uppercaseString];
        strAddress = [strSelectedSingleDeviceAddres uppercaseString];
        
        if ([manuStr length]>=26)
        {
            NSRange RANGEKP = NSMakeRange(18, 4);
            NSString * strAddedd = [manuStr substringWithRange:RANGEKP];
            if ([strAddedd isEqualToString:@"1700"])
            {
                NSRange range71 = NSMakeRange(6, 4);
                NSString * strHexDeviceID = [manuStr substringWithRange:range71];
                
                [saveTimoutTimer invalidate];
                saveTimoutTimer = nil;
                saveTimoutTimer = [NSTimer scheduledTimerWithTimeInterval:7 target:self selector:@selector(TimeOutForDeviceSave) userInfo:nil repeats:NO];

                if ([strHexDeviceID length]>=4)
                {
                    NSString * str1 = [strHexDeviceID substringWithRange:NSMakeRange(0, 2)];
                    NSString * str2 = [strHexDeviceID substringWithRange:NSMakeRange(2, 2)];
                    
                    NSString * strConverted = [NSString stringWithFormat:@"%@%@",str2,str1];
                    unsigned result = 0;
                    NSScanner *scanner = [NSScanner scannerWithString:strConverted];
                    [scanner scanHexInt:&result];
                    newDeviceID = [NSString stringWithFormat:@"%u",result];
                    
                    if ([manuStr length]>37)
                    {
                        range71 = NSMakeRange([manuStr length]-4, 4);
                        NSString * strType = [manuStr substringWithRange:range71];
                        [self getDeviceTypes:strType];
                    }
                    else
                    {
                        [self getDeviceTypes:@"0100"];
                    }
                    NSString * msgPlaceHolder = [NSString stringWithFormat:@"Enter Device Name"];
                    
                    isDeviceResponsed = YES;
                    [saveTimoutTimer invalidate];
                    strHexIdofDevice = strHexDeviceID;

                    [APP_DELEGATE endHudProcess];
                    
                    [alert removeFromSuperview];
                    alert = [[FCAlertView alloc] init];
                    alert.delegate = self;
                    alert.tag = 123;
                    alert.colorScheme = global_brown_color;
                    
                    UITextField *customField = [[UITextField alloc] init];
                    customField.placeholder = msgPlaceHolder;
                    customField.keyboardAppearance = UIKeyboardAppearanceAlert;
                    customField.textColor = [UIColor blackColor];
                    [APP_DELEGATE getPlaceholderText:customField andColor:[UIColor lightGrayColor]];

                    //                        customField.text = strRename;
                    [alert addTextFieldWithCustomTextField:customField andPlaceholder:nil andTextReturnBlock:^(NSString *text) {
                        strDeviceNames = text;
                    }];
                    [alert showAlertInView:self
                                 withTitle:@"Smart Light"
                              withSubtitle:@"Enter name"
                           withCustomImage:nil
                       withDoneButtonTitle:nil
                                andButtons:nil];
                }
            }
            else
            {
                connectionTrialCount = 0;
                [saveTimoutTimer invalidate];
                saveTimoutTimer = nil;
                saveTimoutTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(TimeOutForDeviceSave) userInfo:nil repeats:NO];

                if (globalPeripheral.state == CBPeripheralStateConnected)
                {
                    [self AssociateSingleDevice:manuStr withDeviceName:p.name];
                }
                else
                {
                    [retryConnectTimer invalidate];
                    retryConnectTimer = nil;
                    retryConnectTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(RetryAddingDeviceOnceConnected:) userInfo:@{@"menuStr": manuStr, @"name" : p.name} repeats:YES];
                }
            }
        }
    }
}
-(void)RetryAddingDeviceOnceConnected:(NSTimer*)timer
{
    NSDictionary * tmpDict = [[timer userInfo] mutableCopy];
    if (globalPeripheral.state == CBPeripheralStateConnected)
    {
        NSLog(@"<-------RetryConnectDeviceHappend  Connected-------->%@",[timer userInfo]);

        [retryConnectTimer invalidate];
        retryConnectTimer = nil;
        
        [saveTimoutTimer invalidate];
        saveTimoutTimer = nil;

        NSString * strMenu = [tmpDict objectForKey:@"menuStr"] ;
        NSString * strName = [tmpDict objectForKey:@"name"] ;
        [self AssociateSingleDevice:strMenu withDeviceName:strName];
    }
    else
    {
        NSLog(@"<-------RetryConnectDeviceHappend Not Connected-------->%@",[timer userInfo]);

        connectionTrialCount = connectionTrialCount + 1;
        if (connectionTrialCount < 3)
        {
        }
        else
        {
            [APP_DELEGATE endHudProcess];
            [APP_DELEGATE hideScannerView];
                [retryConnectTimer invalidate];
                retryConnectTimer = nil;

            [saveTimoutTimer invalidate];
            saveTimoutTimer = nil;

            [alert removeFromSuperview];
            alert = [[FCAlertView alloc] init];
            alert.colorScheme = [UIColor blackColor];
            [alert makeAlertTypeCaution];
            [alert showAlertInView:self
                         withTitle:@"Smart Light"
                      withSubtitle:@"Something went wrong. Please try again later."
                   withCustomImage:[UIImage imageNamed:@"logo.png"]
               withDoneButtonTitle:nil
                        andButtons:nil];
        }
    }
}
#pragma mark - BLE Methods
-(void)InitialBLE
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"CallNotificationforNonConnectforAdd" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"deviceDidDisConnectNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"deviceDidConnectNotification" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CallNotificationforNonConnectforAdd:) name:@"CallNotificationforNonConnectforAdd" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(DeviceDidConnectNotification:) name:@"deviceDidConnectNotification" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(DeviceDidDisConnectNotification:) name:@"deviceDidDisConnectNotification" object:nil];
}
-(void)specificNotify:(NSNotification*)notification
{
    NSDictionary *dict = [notification userInfo];
}
#pragma mark - CentralManager Ble delegate Methods
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    
}
#pragma mark - SCANNED DEVICE AFTER SENT REQUEST RESULT APPEAR HERE...LOGIC TO CHECK SCANNED DEVICE

-(void)CallNotificationforNonConnectforAdd:(NSNotification*)notification//Update peripheral
{
    NSDictionary *dict = [notification userInfo];
    if (isAssociated)
    {
        [self CallbackforSingleDeviceAssociationRequestwithData:dict];
    }
    if ([[[BLEManager sharedManager] nonConnectArr] count]>totalCounts)
    {
    [[[BLEManager sharedManager] nonConnectArr] sortUsingDescriptors:
     @[
         [NSSortDescriptor sortDescriptorWithKey:@"isAdded" ascending:YES],
     ]];
        [tblView reloadData];
        totalCounts= totalCounts + 1;
    }
    if ([[[BLEManager sharedManager] nonConnectArr] count]>0)
    {
        [topPullToRefreshManager tableViewReloadFinishedAnimated:NO];
        lblSuccessMsg.hidden = YES;
        [APP_DELEGATE endHudProcess];
        [spinTimer invalidate];
        [tblView reloadData];
        tblView.hidden = NO;
    }
    else
    {
        lblSuccessMsg.hidden = NO;
        [tblView reloadData];
    }
}
-(void)CallbackforSingleDeviceAssociationRequestwithData:(NSDictionary *)dict
{
    NSData *nameData = [dict valueForKey:@"kCBAdvDataManufacturerData"];
    NSString * checkStr = [NSString stringWithFormat:@"%@",nameData.debugDescription];

    NSArray * tmpArr = [checkStr componentsSeparatedByString:@"0a00"];
    if ([checkStr length] > 20)
    {
        NSString *nameString = [NSString stringWithFormat:@"%@",checkStr]; //this works
        NSRange rangeFirst = NSMakeRange(1, 4);
        NSString * strOpCodeCheck = [nameString substringWithRange:rangeFirst];
        if ([strOpCodeCheck isEqualToString:@"0a00"])
        {
            strHexIdofDevice = [self getHaxConvertedfromNormanlString:newDeviceID];
            NSString * kpstr = [tmpArr objectAtIndex:1];
            if ([tmpArr count]>2)
            {
                NSRange range71 = NSMakeRange(4, [checkStr length]-4);
                kpstr = [checkStr substringWithRange:range71];
            }
            kpstr = [kpstr stringByReplacingOccurrencesOfString:@" " withString:@""];
            kpstr = [kpstr stringByReplacingOccurrencesOfString:@">" withString:@""];
            kpstr = [kpstr stringByReplacingOccurrencesOfString:@"<" withString:@""];

            NSString * strKeys;
            if ([strDestID isEqualToString:@"0000"])
            {
                strKeys = [APP_DELEGATE getStringConvertedinUnsigned:[[NSUserDefaults standardUserDefaults]valueForKey:@"VDK"]];
            }
            else
            {
                strKeys = [APP_DELEGATE getStringConvertedinUnsigned:[[NSUserDefaults standardUserDefaults]valueForKey:@"passKey"]];
            }
            NSString * strFinalData = [APP_DELEGATE getStringConvertedinUnsigned:kpstr];
            NSData * updatedMFData = [APP_DELEGATE GetDecrypedDataKeyforData:strFinalData withKey:strKeys withLength:[kpstr length]/2];
            NSString * strDecrypted = [NSString stringWithFormat:@"%@",updatedMFData.debugDescription];
            
            strDecrypted = [strDecrypted stringByReplacingOccurrencesOfString:@" " withString:@""];
            strDecrypted = [strDecrypted stringByReplacingOccurrencesOfString:@">" withString:@""];
            strDecrypted = [strDecrypted stringByReplacingOccurrencesOfString:@"<" withString:@""];
            nameString = [NSString stringWithFormat:@"%@",updatedMFData.debugDescription];
            
            if ([strDecrypted rangeOfString:@"3600"].location != NSNotFound)
            {
                if ([strDecrypted rangeOfString:strHexIdofDevice].location == NSNotFound)
                {
                }
                else
                {
                    if (isAllowOnce)
                    {
                    }
                    else
                    {
                        isAllowOnce = YES;
//                        tblView.hidden = YES;
                        
                        NSString * msgPlaceHolder = [NSString stringWithFormat:@"Enter Device Name"];
                        
                        isDeviceResponsed = YES;
                        [saveTimoutTimer invalidate];
                        
                        [APP_DELEGATE endHudProcess];

                        [alert removeFromSuperview];
                        alert = [[FCAlertView alloc] init];
                        alert.delegate = self;
                        alert.tag = 123;
                        alert.colorScheme = global_brown_color;
                        
                        UITextField *customField = [[UITextField alloc] init];
                        customField.placeholder = msgPlaceHolder;
                        customField.keyboardAppearance = UIKeyboardAppearanceAlert;
                        customField.textColor = [UIColor blackColor];

                        [APP_DELEGATE getPlaceholderText:customField andColor:[UIColor lightGrayColor]];

//                        customField.text = strRename;
                        [alert addTextFieldWithCustomTextField:customField andPlaceholder:nil andTextReturnBlock:^(NSString *text) {
                            strDeviceNames = text;
                        }];
                        [alert showAlertInView:self
                                     withTitle:@"Smart Light"
                                  withSubtitle:@"Enter name"
                               withCustomImage:nil
                           withDoneButtonTitle:nil
                                    andButtons:nil];
                    }
                }
            }
            else
            {
                NSArray * tmpArr = [kpstr componentsSeparatedByString:@"1700"];
                if ([tmpArr count]>1)
                {
                    NSString * kpstr = [tmpArr objectAtIndex:0];
                    kpstr = [kpstr stringByReplacingOccurrencesOfString:@" " withString:@""];
                    kpstr = [kpstr stringByReplacingOccurrencesOfString:@">" withString:@""];
                    if ([kpstr length]>=14)
                    {
                        if ([kpstr rangeOfString:strHexIdofDevice].location == NSNotFound)
                        {
                        }
                        else
                        {
                            if (isAllowOnce)
                            {
                            }
                            else
                            {
                                isAllowOnce = YES;
//                                tblView.hidden = YES;
                                
                                NSString * msgPlaceHolder = [NSString stringWithFormat:@"Enter Device Name"];
                                
                                isDeviceResponsed = YES;
                                [saveTimoutTimer invalidate];

                                [APP_DELEGATE endHudProcess];
                                
                                [alert removeFromSuperview];
                                alert = [[FCAlertView alloc] init];
                                alert.delegate = self;
                                alert.tag = 123;
                                alert.colorScheme = global_brown_color;
                                
                                UITextField *customField = [[UITextField alloc] init];
                                customField.placeholder = msgPlaceHolder;
                                customField.keyboardAppearance = UIKeyboardAppearanceAlert;
                                customField.textColor = [UIColor blackColor];

                                [APP_DELEGATE getPlaceholderText:customField andColor:[UIColor lightGrayColor]];

                                //                        customField.text = strRename;
                                [alert addTextFieldWithCustomTextField:customField andPlaceholder:nil andTextReturnBlock:^(NSString *text) {
                                    strDeviceNames = text;
                                }];
                                [alert showAlertInView:self
                                             withTitle:@"Smart Light"
                                          withSubtitle:@"Enter name"
                                       withCustomImage:nil
                                   withDoneButtonTitle:nil
                                            andButtons:nil];
//                                [self SaveSingleDeviceDetailstoDatabase:strHexIdofDevice];
                            }
                        }
                    }
                }
            }
        }
    }
}
-(void)SaveSingleDeviceDetailstoDatabase:(NSString *)strHexDeviceId
{
    NSString * strType = [self getDeviceName];
    strAddress = [strAddress uppercaseString];
    if ([[deviceListArray valueForKey:@"ble_address"] containsObject:strAddress])
    {
        NSString * strUpdate = [NSString stringWithFormat:@"update Device_Table set device_id = '%@', hex_device_id ='%@',device_name='%@', status ='1', is_sync = '0' where ble_address = '%@'",newDeviceID,strHexDeviceId,strDeviceNames,strAddress];
        [[DataBaseManager dataBaseManager] execute:strUpdate];
    }
    else
    {
        isDeviceResponsed = YES;
        
        NSString * requestStr =[NSString stringWithFormat:@"insert into 'Device_Table'('device_id','hex_device_id','real_name','device_name','ble_address','device_type','device_type_name','switch_status','user_id','is_favourite','is_sync',status, 'remember_last_color') values('%@','%@','%@',\"%@\",\"%@\",'%@','%@','Yes','%@','2','0','1','0')",newDeviceID,strHexDeviceId,strDeviceNames,strDeviceNames, [strAddress uppercaseString] ,strType,strDeviceType,CURRENT_USER_ID];
        
         [[DataBaseManager dataBaseManager] executeSw:requestStr];
    }
    if (![IS_USER_SKIPPED isEqualToString:@"YES"])
    {
        [self SaveDeviceWebservicedeviceID:newDeviceID hexId:strHexDeviceId devName:strDeviceNames type:strType withAddress:strAddress withDeviceArr:nil];
    }
    else
    {
        [APP_DELEGATE hideScannerView];
        [APP_DELEGATE endHudProcess];

        [alert removeFromSuperview];
        alert = [[FCAlertView alloc] init];
        alert.colorScheme = [UIColor blackColor];
        [alert makeAlertTypeSuccess];
        alert.delegate = self;
        alert.tag = 222;
        [alert showAlertInView:self
                     withTitle:@"Smart Light"
                  withSubtitle:@"Device has been added successfully."
               withCustomImage:[UIImage imageNamed:@"logo.png"]
           withDoneButtonTitle:nil
                    andButtons:nil];
    }
}
#pragma mark - Ble device Disconnect method
-(void)onDisconnectWithDevice:(CBPeripheral*)peripheral
{
    [[BLEManager sharedManager] disconnectDevice:peripheral];
}

#pragma mark - Ble device Connect method
-(void)onConnectWithDevice:(CBPeripheral*)peripheral
{
    [[BLEManager sharedManager] connectDevice:peripheral];
}

#pragma mark - Webservice Methods
-(void)SaveDeviceWebservicedeviceID:(NSString *)devID hexId:(NSString*)hexId devName:(NSString *)name type:(NSString *)type withAddress:(NSString *)bleAddress withDeviceArr:(NSMutableArray *)deviveArr
{
    if ([APP_DELEGATE isNetworkreachable])
    {
        NSMutableDictionary * dict = [[NSMutableDictionary alloc]init];
        [dict setValue:CURRENT_USER_ID forKey:@"user_id"];
        [dict setValue:devID forKey:@"device_id"];
        [dict setValue:hexId forKey:@"hex_device_id"];
        [dict setValue:name forKey:@"device_name"];
        [dict setValue:type forKey:@"device_type"];
        [dict setValue:[bleAddress uppercaseString] forKey:@"ble_address"];
        [dict setValue:@"1" forKey:@"status"];
        [dict setValue:@"2" forKey:@"is_favourite"];
        [dict setValue:@"0" forKey:@"is_update"];
        [dict setValue:@"0" forKey:@"remember_last_color"];

        
        NSString *deviceToken =deviceTokenStr;
        if (deviceToken == nil || deviceToken == NULL)
        {
            [dict setValue:@"123456789" forKey:@"device_token"];
        }
        else
        {
            [dict setValue:deviceToken forKey:@"device_token"];
        }
        URLManager *manager = [[URLManager alloc] init];
        manager.commandName = @"SaveDevice";
        manager.delegate = self;
        NSString *strServerUrl = @"http://vithamastech.com/smartlight/api/save_device";
        [manager urlCall:strServerUrl withParameters:dict];
    }
    else
    {
        [APP_DELEGATE hideScannerView];
        [APP_DELEGATE endHudProcess];
        
        [alert removeFromSuperview];
        alert = [[FCAlertView alloc] init];
        alert.colorScheme = [UIColor blackColor];
        [alert makeAlertTypeSuccess];
        alert.delegate = self;
        alert.tag = 222;
        [alert showAlertInView:self
                     withTitle:@"Smart Light"
                  withSubtitle:@"Device has been added successfully."
               withCustomImage:[UIImage imageNamed:@"logo.png"]
           withDoneButtonTitle:nil
                    andButtons:nil];
    }
}



#pragma mark - UrlManager Delegate
- (void)onResult:(NSDictionary *)result
{
    [topPullToRefreshManager tableViewReloadFinishedAnimated:NO];

    [APP_DELEGATE hideScannerView];
    [APP_DELEGATE endHudProcess];
    
//    NSLog(@"The result is...%@", result);
    if ([[result valueForKey:@"commandName"] isEqualToString:@"SaveDevice"])
    {
        if ([[[result valueForKey:@"result"] valueForKey:@"response"] isEqualToString:@"true"])
        {
            if([[result valueForKey:@"result"] valueForKey:@"data"]!=[NSNull null] || [[result valueForKey:@"result"] valueForKey:@"data"] != nil)
            {
                NSString * strServerId = [self checkforValidString:[[[result valueForKey:@"result"] valueForKey:@"data"] valueForKey:@"server_device_id"]];
                NSString * strUserId = [self checkforValidString:[[[result valueForKey:@"result"] valueForKey:@"data"] valueForKey:@"user_id"]];
                NSString * strDeviceId = [self checkforValidString:[[[result valueForKey:@"result"] valueForKey:@"data"] valueForKey:@"device_id"]];
                NSString * strCreatedDate = [self checkforValidString:[[[result valueForKey:@"result"] valueForKey:@"data"] valueForKey:@"created_date"]];
                NSString * strUpdatedDate = [self checkforValidString:[[[result valueForKey:@"result"] valueForKey:@"data"] valueForKey:@"updated_date"]];
                NSString * strTimeStamp = [self checkforValidString:[[[result valueForKey:@"result"] valueForKey:@"data"] valueForKey:@"timestamp"]];
                NSString * strBleAddress = [self checkforValidString:[[[result valueForKey:@"result"] valueForKey:@"data"] valueForKey:@"ble_address"]];

                NSString * strQuery = [NSString stringWithFormat:@"update Device_Table set server_device_id = '%@', created_at = '%@', updated_at = '%@', timestamp = '%@',is_sync='1' where user_id = '%@' and ble_address ='%@'",strServerId,strCreatedDate,strUpdatedDate,strTimeStamp,strUserId, strBleAddress];
                [[DataBaseManager dataBaseManager] execute:strQuery];
                
                [alert removeFromSuperview];
                alert = [[FCAlertView alloc] init];
                alert.colorScheme = [UIColor blackColor];
                [alert makeAlertTypeSuccess];
                alert.delegate = self;
                alert.tag = 222;
                [alert showAlertInView:self
                             withTitle:@"Smart Light"
                          withSubtitle:@"Device has been added successfully."
                       withCustomImage:[UIImage imageNamed:@"logo.png"]
                   withDoneButtonTitle:nil
                            andButtons:nil];
            }
        }
        else
        {
            [alert removeFromSuperview];
            alert = [[FCAlertView alloc] init];
            alert.colorScheme = [UIColor blackColor];
            [alert makeAlertTypeSuccess];
            alert.delegate = self;
            alert.tag = 222;
            [alert showAlertInView:self
                         withTitle:@"Smart Light"
                      withSubtitle:@"Device has been added successfully."
                   withCustomImage:[UIImage imageNamed:@"logo.png"]
               withDoneButtonTitle:nil
                        andButtons:nil];

        }
    }
    
}
- (void)onError:(NSError *)error
{
    [topPullToRefreshManager tableViewReloadFinishedAnimated:NO];

    [APP_DELEGATE hideScannerView];
    [APP_DELEGATE endHudProcess];

//    NSLog(@"The error is...%@", error);
    
    NSInteger ancode = [error code];
    
    NSMutableDictionary * errorDict = [error.userInfo mutableCopy];
//    NSLog(@"errorDict===%@",errorDict);
    
    if (ancode == -1001 || ancode == -1004 || ancode == -1005 || ancode == -1009)
    {
//        [APP_DELEGATE ShowErrorPopUpWithErrorCode:ancode andMessage:@""];
    }
    else
    {
//        [APP_DELEGATE ShowErrorPopUpWithErrorCode:customErrorCodeForMessage andMessage:@"Please try again later"];
    }
    
    NSString * strLoginUrl = [NSString stringWithFormat:@"%@%@",WEB_SERVICE_URL,@"token.json"];
    if ([[errorDict valueForKey:@"NSErrorFailingURLStringKey"] isEqualToString:strLoginUrl])
    {
//        NSLog(@"NSErrorFailingURLStringKey===%@",[errorDict valueForKey:@"NSErrorFailingURLStringKey"]);
    }
    [alert removeFromSuperview];
    alert = [[FCAlertView alloc] init];
    alert.colorScheme = [UIColor blackColor];
    [alert makeAlertTypeSuccess];
    alert.delegate = self;
    alert.tag = 222;
    [alert showAlertInView:self
                 withTitle:@"Smart Light"
              withSubtitle:@"Device has been added successfully."
           withCustomImage:[UIImage imageNamed:@"logo.png"]
       withDoneButtonTitle:nil
                andButtons:nil];

}
#pragma mark - BLE EXTRA METHODS
-(NSString *)checkforValidString:(NSString *)strRequest
{
    NSString * strValid;
    if (![strRequest isEqual:[NSNull null]])
    {
        if (strRequest != nil && strRequest != NULL && ![strRequest isEqualToString:@""])
        {
            strValid = strRequest;
        }
        else
        {
            strValid = @"NA";
        }
    }
    else
    {
        strValid = @"NA";
    }
    return strValid;
}

-(void)didDiscoverPeripheralNotification:(NSNotification*)notification//Update peripheral
{
    if ([[[BLEManager sharedManager] nonConnectArr] count] >0)
    {
        lblSuccessMsg.hidden = YES;
        tblView.hidden = YES;
//        [APP_DELEGATE hideScannerView];
//        [APP_DELEGATE endHudProcess];
    }
    else
    {
        lblSuccessMsg.hidden = YES;
        tblView.hidden = YES;
    }
    [tblView reloadData];
}
-(void)DeviceDidConnectNotification:(NSNotification*)notification//Connect periperal
{
//    [[BLEService sharedInstance] sendNotifications:myPeripheral withType:NO];
    [tblView reloadData];
}

-(void)DeviceDidDisConnectNotification:(NSNotification*)notification//Disconnect periperal
{
    [tblView reloadData];
}

-(void)onConnectButton:(NSInteger)sender//Connect & DisconnectClicked
{
    
}


-(NSString*)hexFromStr:(NSString*)str
{
    NSData* nsData = [str dataUsingEncoding:NSUTF8StringEncoding];
    const char* data = [nsData bytes];
    NSUInteger len = nsData.length;
    NSMutableString* hex = [NSMutableString string];
    for(int i = 0; i < len; ++i)
        [hex appendFormat:@"%02X", data[i]];
    return hex;
}

- (NSData *)dataFromHexString:(NSString*)hexStr
{
    const char *chars = [hexStr UTF8String];
    int i = 0, len = hexStr.length;
    
    NSMutableData *data = [NSMutableData dataWithCapacity:len / 2];
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte;
    
    while (i < len) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        [data appendBytes:&wholeByte length:1];
    }
    
    return data;
}
-(void)showBridgeScreen
{
    BridgeVC * bridgV = [[BridgeVC alloc] init];
    bridgV.isFromAddDevice = YES;
    [self.navigationController pushViewController:bridgV animated:YES];
}
-(void)updateBleStatus
{
    if (globalConnStatus)
    {
        statusImg.image = [UIImage imageNamed:@"Connected_icon.png"];
    }
    else
    {
        statusImg.image = [UIImage imageNamed:@"notconnect_icon.png"];
    }
}

-(NSString *)getHaxConvertedfromNormanlString:(NSString *)strNormal
{
    NSString * str = @"NA";
    
    NSString *hexStr = [NSString stringWithFormat:@"%lX",
                        (unsigned long)[strNormal integerValue]];
    
    unsigned long long startlong;
    NSScanner* scanner1 = [NSScanner scannerWithString:hexStr];
    [scanner1 scanHexLongLong:&startlong];
    double unixStart = startlong;
    NSNumber * startNumber = [[NSNumber alloc] initWithDouble:unixStart];
    NSInteger int71 = [startNumber integerValue];
    NSData * data71 = [[NSData alloc] initWithBytes:&int71 length:2];
//    NSLog(@"%@", [NSString stringWithFormat:@"%@", data71]);
    
    NSString * strFinal = [NSString stringWithFormat:@"%@", data71.debugDescription];
    strFinal = [strFinal stringByReplacingOccurrencesOfString:@" " withString:@""];
    strFinal = [strFinal stringByReplacingOccurrencesOfString:@">" withString:@""];
    strFinal = [strFinal stringByReplacingOccurrencesOfString:@"<" withString:@""];
    str = strFinal;
    return str;
}
-(NSString *)getDeviceName
{
    NSString * strType = @"1";
    if ([strDeviceType isEqualToString:@"Bulb"])
    {
        strType = @"1";
    }
    else if ([strDeviceType isEqualToString:@"WhiteLight"])
    {
        strType = @"2";
    }
    else if ([strDeviceType isEqualToString:@"Switch"])
    {
        strType = @"3";
    }
    else if ([strDeviceType isEqualToString:@"PowerSocket"])
    {
        strType = @"4";
    }
    else if ([strDeviceType isEqualToString:@"Fan"])
    {
        strType = @"5";
    }
    else if ([strDeviceType isEqualToString:@"StripLight"])
    {
        strType = @"6";
    }
    else if ([strDeviceType isEqualToString:@"NightLamp"])
    {
        strType = @"7";
    }
    else if ([strDeviceType isEqualToString:@"PowerStrip"])
    {
        strType = @"8";
    }
    return strType;
}
-(void)getDeviceTypes:(NSString *)strType
{
    if ([strType isEqualToString:@"0100"])
    {
        strDeviceType = @"Bulb";
    }
    else if ([strType isEqualToString:@"0200"])
    {
        strDeviceType = @"WhiteLight";
    }
    else if ([strType isEqualToString:@"0300"])
    {
        strDeviceType = @"Switch";
    }
    else if ([strType isEqualToString:@"0400"])
    {
        strDeviceType = @"PowerSocket";
    }
    else if ([strType isEqualToString:@"0500"])
    {
        strDeviceType = @"Fan";
    }
    else if ([strType isEqualToString:@"0600"])
    {
        strDeviceType = @"StripLight";
    }
    else if ([strType isEqualToString:@"0700"])
    {
        strDeviceType = @"NightLamp";
    }
    else if ([strType isEqualToString:@"0800"])
    {
        strDeviceType = @"PowerStrip";
    }
}
-(void)GlobalBLuetoothCheck
{
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Vithamas" message:@"Please enable Bluetooth Connection. Tap on enable Bluetooth icon by swiping Up." preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
    [alertController addAction:defaultAction];
    [self presentViewController:alertController animated:true completion:nil];
}
#pragma mark - Helper Methods

- (void)FCAlertView:(FCAlertView *)alertView clickedButtonIndex:(NSInteger)index buttonTitle:(NSString *)title
{
}

- (void)FCAlertDoneButtonClicked:(FCAlertView *)alertView
{
    if (alertView.tag == 222)
    {
        [self.navigationController popViewControllerAnimated:YES];
    }
    else if (alertView.tag == 125)
    {
        [self refreshBtnClick];
    }
    else  if (alertView.tag == 123)
    {
        [self ValidationforAddedMessage:strDeviceNames];
    }
}

- (void)FCAlertViewDismissed:(FCAlertView *)alertView
{
}

- (void)FCAlertViewWillAppear:(FCAlertView *)alertView
{
}
-(void)ValidationforAddedMessage:(NSString *)text
{
    if ([[self checkforValidString:text] isEqualToString:@"NA"])
    {
//        [self showErrorMessage:@"Please enter valid name."];
        
        [alert removeFromSuperview];
        alert = [[FCAlertView alloc] init];
        alert.delegate = self;
        alert.tag = 123;
        alert.colorScheme = global_brown_color;
        
        UITextField *customField = [[UITextField alloc] init];
        customField.placeholder = @"Enter Device Name";
        customField.keyboardAppearance = UIKeyboardAppearanceAlert;
        //                        customField.text = strRename;
        [alert addTextFieldWithCustomTextField:customField andPlaceholder:nil andTextReturnBlock:^(NSString *text) {
            strDeviceNames = text;
        }];
        [alert showAlertInView:self
                     withTitle:@"Smart Light"
                  withSubtitle:@"Please Enter name"
               withCustomImage:nil
           withDoneButtonTitle:nil
                    andButtons:nil];
    }
    else
    {
        [self SaveSingleDeviceDetailstoDatabase:strHexIdofDevice];
    }
}
-(void)showErrorMessage:(NSString *)strMessage
{
    FCAlertView *alert = [[FCAlertView alloc] init];
    alert.colorScheme = [UIColor blackColor];
    [alert makeAlertTypeWarning];
    [alert showAlertInView:self
                 withTitle:@"Smart Light"
              withSubtitle:strMessage
           withCustomImage:[UIImage imageNamed:@"logo.png"]
       withDoneButtonTitle:nil
                andButtons:nil];
}
-(void)sendTesetingRequest:(NSString *)stringss withDeviceName:(NSString *)deviceName
{
    if ([stringss length]>=38)
    {
        NSString * kpstr = stringss;
        kpstr = [kpstr stringByReplacingOccurrencesOfString:@" " withString:@""];
        kpstr = [kpstr stringByReplacingOccurrencesOfString:@">" withString:@""];
        
        NSRange range1 = NSMakeRange(0, 2);
        strTTL = [kpstr substringWithRange:range1];
        NSInteger int1 = [@"100" integerValue];
        NSData * data1 = [[NSData alloc] initWithBytes:&int1 length:1];
        
        NSRange range2 = NSMakeRange(2, 4);
        strSqence = [kpstr substringWithRange:range2];
        globalCount = globalCount + 1;
        NSInteger int2 = [@"1432" integerValue];
        NSData * data2 = [[NSData alloc] initWithBytes:&int2 length:2];
        
        NSRange range3 = NSMakeRange(6, 4);
        strDevId = [kpstr substringWithRange:range3];
        NSInteger int3 = [@"0000" integerValue];
        NSData * data3 = [[NSData alloc] initWithBytes:&int3 length:2];
        
        /*NSRange range4 = NSMakeRange(10, 4);
         strDestID = [kpstr substringWithRange:range4];*/
        NSInteger int4 = [@"0000" integerValue];
        NSData * data4 = [[NSData alloc] initWithBytes:&int4 length:2];
        
        /*NSRange range5 = NSMakeRange(14, 4);
         strCrc = [kpstr substringWithRange:range5];
         NSInteger int5 = [strCrc integerValue];
         NSData * data5 = [[NSData alloc] initWithBytes:&int5 length:2];*/
        
        NSRange range6 = NSMakeRange(18, 4);
        strOpCode = [kpstr substringWithRange:range6];
        NSInteger int6 = [@"49" integerValue];
        NSData * data6 = [[NSData alloc] initWithBytes:&int6 length:2];
        
        NSRange range7 = NSMakeRange(22, 12);
        strAddress = [kpstr substringWithRange:range7];
        
        NSRange range71 = NSMakeRange(0, 4);
        NSString * str1 = [strAddress substringWithRange:range71];
        
        unsigned long long startlong;
        NSScanner* scanner1 = [NSScanner scannerWithString:str1];
        [scanner1 scanHexLongLong:&startlong];
        double unixStart = startlong;
        NSNumber * startNumber = [[NSNumber alloc] initWithDouble:unixStart];
        NSInteger int71 = [startNumber integerValue];
        NSData * data71 = [[NSData alloc] initWithBytes:&int71 length:2];
        
        NSRange range72 = NSMakeRange(4, 4);
        NSString * str2 = [strAddress substringWithRange:range72];
        scanner1 = [NSScanner scannerWithString:str2];
        [scanner1 scanHexLongLong:&startlong];
        unixStart = startlong;
        startNumber = [[NSNumber alloc] initWithDouble:unixStart];
        NSInteger int72 = [startNumber integerValue];
        NSData * data72 = [[NSData alloc] initWithBytes:&int72 length:2];
        
        NSRange range73 = NSMakeRange(8, 4);
        NSString * str3 = [strAddress substringWithRange:range73];
        scanner1 = [NSScanner scannerWithString:str3];
        [scanner1 scanHexLongLong:&startlong];
        unixStart = startlong;
        startNumber = [[NSNumber alloc] initWithDouble:unixStart];
        NSInteger int73 = [startNumber integerValue];
        NSData * data73 = [[NSData alloc] initWithBytes:&int73 length:2];
        
        NSMutableData * fData = [[NSMutableData alloc] init];
        fData = [data71 mutableCopy];
        [fData appendData:data72];
        [fData appendData:data73];
        
        /*int randomID = arc4random() % 9000 + 1000;
         
         NSInteger int8 = randomID;
         NSData * data8 = [[NSData alloc] initWithBytes:&int8 length:2];
         newDeviceID = [NSString stringWithFormat:@"%ld",(long)int8];
         isAssociated = YES;
         NSLog(@"newDeviceID=%@",newDeviceID);*/
        
        if ([stringss length]>=38)
        {
            NSRange range71 = NSMakeRange(34, 4);
            NSString * strType = [kpstr substringWithRange:range71];
            
            [self getDeviceTypes:strType];
        }
        //Count Checksum
        
        NSMutableData * checkData = [[NSMutableData alloc] init];
        [checkData appendData:data2];
        [checkData appendData:data3];
        [checkData appendData:data4];
        [checkData appendData:data4];//CRC
        [checkData appendData:data6];
        
        NSString * keyfirst = [[NSUserDefaults standardUserDefaults] valueForKey:@"passKey"];
        NSData * encryptKeyData= [[NSData alloc] init];
        if ([keyfirst length]>30)
        {
            NSRange rangeFirst = NSMakeRange(0, 16);
            NSString * strVithCheck = [keyfirst substringWithRange:rangeFirst];
            encryptKeyData = [self getUserKeyconverted:strVithCheck];
        }
        [checkData appendData:encryptKeyData];
        
        
        NSData * checksumData = [APP_DELEGATE GetCountedCheckSumData:checkData];
        //            [APP_DELEGATE GetCountedCheckSumDataCRC16:checkData];
        
        NSMutableData * completeData = [[NSMutableData alloc] init];
        completeData = [data1 mutableCopy];
        [completeData appendData:data2];
        [completeData appendData:data3];
        [completeData appendData:data4];
        [completeData appendData:checksumData];
        [completeData appendData:data6];
        [completeData appendData:encryptKeyData];
        
        
        NSString * StrData = [NSString stringWithFormat:@"%@",completeData.debugDescription];
        StrData = [StrData stringByReplacingOccurrencesOfString:@" " withString:@""];
        StrData = [StrData stringByReplacingOccurrencesOfString:@"<" withString:@""];
        StrData = [StrData stringByReplacingOccurrencesOfString:@">" withString:@""];
        
        //            for (int i=0; i<40-[StrData length]; i++)
        //            {
        //                StrData = [StrData stringByAppendingString:@"00"];
        //            }
//        NSLog(@"RAW DATA=%@",StrData);
        
        for (int i=0; i<32-[strAddress length]; i++)
        {
            strAddress = [strAddress stringByAppendingString:@"00"];
        }
        
        NSString * strEncryptedKey = [APP_DELEGATE getStringConvertedinUnsigned:[[NSUserDefaults standardUserDefaults] valueForKey:@"passKey"]];
        
        NSString * strFinalData = [APP_DELEGATE getStringConvertedinUnsigned:StrData];
        NSData * requestData = [APP_DELEGATE SendAssociationRequestFirst:strFinalData withKey:strEncryptedKey withBLEAddress:[APP_DELEGATE getStringConvertedinUnsigned:strAddress] withRawDataLength:completeData.length];
        
        [[BLEService sharedInstance] writeValuetoDeviceMsg:requestData with:globalPeripheral];
        [[NSUserDefaults standardUserDefaults] setInteger:globalCount forKey:@"GlobalCount"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        strAddress =  [strAddress uppercaseString];
        strDeviceNames  = deviceName;
        
        [self sendSecondPartofKey:kpstr];
    }
    else
    {
        [APP_DELEGATE hideScannerView];
        [APP_DELEGATE endHudProcess];
        
        [alert removeFromSuperview];
        alert = [[FCAlertView alloc] init];
        alert.colorScheme = [UIColor blackColor];
        [alert makeAlertTypeCaution];
        [alert showAlertInView:self
                     withTitle:@"Smart Light"
                  withSubtitle:@"Something went wrong. Please try again later."
               withCustomImage:[UIImage imageNamed:@"logo.png"]
           withDoneButtonTitle:nil
                    andButtons:nil];
    }
    
}
-(NSData *)getUserKeyconverted:(NSString *)strAddress
{
    NSMutableData * keyData = [[NSMutableData alloc] init];
    
    for (int i=0; i<8; i++)
    {
        NSRange rangeFirst = NSMakeRange(i*2, 2);
        NSString * strVithCheck = [strAddress substringWithRange:rangeFirst];
        
        unsigned long long startlong;
        NSScanner * scanner1 = [NSScanner scannerWithString:strVithCheck];
        [scanner1 scanHexLongLong:&startlong];
        double unixStart = startlong;
        NSNumber * startNumber = [[NSNumber alloc] initWithDouble:unixStart];
        NSInteger int72 = [startNumber integerValue];
        NSData * data72 = [[NSData alloc] initWithBytes:&int72 length:1];
        if (i==0)
        {
            keyData= [data72 mutableCopy];
        }
        else
        {
            [keyData appendData:data72];
        }
    }

    return keyData;
}
-(void)ConnectionValidationPopup
{
    [alert removeFromSuperview];
    alert = [[FCAlertView alloc] init];
    alert.colorScheme = [UIColor blackColor];
    [alert makeAlertTypeCaution];
    [alert addButton:@"Go to Connect" withActionBlock:^{
        
        isMovedforConnection = YES;
        BridgeVC * bridge = [[BridgeVC alloc] init];
        bridge.isFromAddDevice = YES;
        [self.navigationController pushViewController:bridge animated:YES];
    }];
    alert.firstButtonCustomFont = [UIFont fontWithName:CGRegular size:textSizes];
    [alert showAlertInView:self
                 withTitle:@"Smart Light"
              withSubtitle:@"Your IOS device is not connected with SmartLight device. Please connect first with device."
           withCustomImage:[UIImage imageNamed:@"logo.png"]
       withDoneButtonTitle:@"Ok"
                andButtons:nil];
}
-(void)SengCheckDeviceMethod:(NSString *)stringss withDeviceName:(NSString *)deviceName
{
    if ([stringss length]>=38)
    {
        
        {
            NSString * kpstr = stringss;
            kpstr = [kpstr stringByReplacingOccurrencesOfString:@" " withString:@""];
            kpstr = [kpstr stringByReplacingOccurrencesOfString:@">" withString:@""];
            
            NSRange range1 = NSMakeRange(0, 2);
            strTTL = [kpstr substringWithRange:range1];
            NSInteger int1 = [@"100" integerValue];
            NSData * data1 = [[NSData alloc] initWithBytes:&int1 length:1];
            
            NSRange range2 = NSMakeRange(2, 4);
            strSqence = [kpstr substringWithRange:range2];
            globalCount = globalCount + 1;
            NSInteger int2 = globalCount;
            NSData * data2 = [[NSData alloc] initWithBytes:&int2 length:2];
            
            NSRange range3 = NSMakeRange(6, 4);
            strDevId = [kpstr substringWithRange:range3];
            NSInteger int3 = [@"0000" integerValue];
            NSData * data3 = [[NSData alloc] initWithBytes:&int3 length:2];
            
            /*NSRange range4 = NSMakeRange(10, 4);
             strDestID = [kpstr substringWithRange:range4];*/
            NSInteger int4 = [@"0000" integerValue];
            NSData * data4 = [[NSData alloc] initWithBytes:&int4 length:2];
            
            /*NSRange range5 = NSMakeRange(14, 4);
             strCrc = [kpstr substringWithRange:range5];
             NSInteger int5 = [strCrc integerValue];
             NSData * data5 = [[NSData alloc] initWithBytes:&int5 length:2];*/
            
            NSRange range6 = NSMakeRange(18, 4);
            strOpCode = [kpstr substringWithRange:range6];
            NSInteger int6 = [@"52" integerValue];
            NSData * data6 = [[NSData alloc] initWithBytes:&int6 length:2];
            
            NSRange range7 = NSMakeRange(22, 12);
            strAddress = [kpstr substringWithRange:range7];
            
            NSRange range71 = NSMakeRange(0, 4);
            NSString * str1 = [strAddress substringWithRange:range71];
            
            unsigned long long startlong;
            NSScanner* scanner1 = [NSScanner scannerWithString:str1];
            [scanner1 scanHexLongLong:&startlong];
            double unixStart = startlong;
            NSNumber * startNumber = [[NSNumber alloc] initWithDouble:unixStart];
            NSInteger int71 = [startNumber integerValue];
            NSData * data71 = [[NSData alloc] initWithBytes:&int71 length:2];
            
            NSRange range72 = NSMakeRange(4, 4);
            NSString * str2 = [strAddress substringWithRange:range72];
            scanner1 = [NSScanner scannerWithString:str2];
            [scanner1 scanHexLongLong:&startlong];
            unixStart = startlong;
            startNumber = [[NSNumber alloc] initWithDouble:unixStart];
            NSInteger int72 = [startNumber integerValue];
            NSData * data72 = [[NSData alloc] initWithBytes:&int72 length:2];
            
            NSRange range73 = NSMakeRange(8, 4);
            NSString * str3 = [strAddress substringWithRange:range73];
            scanner1 = [NSScanner scannerWithString:str3];
            [scanner1 scanHexLongLong:&startlong];
            unixStart = startlong;
            startNumber = [[NSNumber alloc] initWithDouble:unixStart];
            NSInteger int73 = [startNumber integerValue];
            NSData * data73 = [[NSData alloc] initWithBytes:&int73 length:2];
            
            NSMutableData * fData = [[NSMutableData alloc] init];
            fData = [data71 mutableCopy];
            [fData appendData:data72];
            [fData appendData:data73];
            
            if ([stringss length]>=38)
            {
                NSRange range71 = NSMakeRange(34, 4);
                NSString * strType = [kpstr substringWithRange:range71];
                
                [self getDeviceTypes:strType];
            }
            
            //Count Checksum
            NSMutableData * checkData = [[NSMutableData alloc] init];
            [checkData appendData:data2];
            [checkData appendData:data3];
            [checkData appendData:data4];
            [checkData appendData:data4];//CRC as 0
            [checkData appendData:data6];
            
            NSData * checksumData = [APP_DELEGATE GetCountedCheckSumData:checkData];
            
            NSMutableData * completeData = [[NSMutableData alloc] init];
            completeData = [data1 mutableCopy];
            [completeData appendData:data2];
            [completeData appendData:data3];
            [completeData appendData:data4];
            [completeData appendData:checksumData];
            [completeData appendData:data6];
            
            NSString * StrData = [NSString stringWithFormat:@"%@",completeData.debugDescription];
            StrData = [StrData stringByReplacingOccurrencesOfString:@" " withString:@""];
            StrData = [StrData stringByReplacingOccurrencesOfString:@"<" withString:@""];
            StrData = [StrData stringByReplacingOccurrencesOfString:@">" withString:@""];
            
            strRequetAddress = strAddress;
            for (int i=0; i<32-[strRequetAddress length]; i++)
            {
                strRequetAddress = [strRequetAddress stringByAppendingString:@"00"];
            }
            
            NSString * strEncryptedKey = [APP_DELEGATE getStringConvertedinUnsigned:@"3A094462FD6210CDE87442CAA9D718F9"];
            NSString * strFinalData = [APP_DELEGATE getStringConvertedinUnsigned:StrData];
            
            NSData * requestData = [APP_DELEGATE SendAssociationRequestFirst:strFinalData withKey:strEncryptedKey withBLEAddress:[APP_DELEGATE getStringConvertedinUnsigned:strRequetAddress] withRawDataLength:completeData.length];
            
            [[BLEService sharedInstance] writeValuetoDeviceMsg:requestData with:globalPeripheral];
            [[NSUserDefaults standardUserDefaults] setInteger:globalCount forKey:@"GlobalCount"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            strAddress =  [strAddress uppercaseString];
            strDeviceNames  = deviceName;
            
            [self sendSecondPartofKey:kpstr];
        }
    }
    else
    {
        [APP_DELEGATE hideScannerView];
        [APP_DELEGATE endHudProcess];
        
        [alert removeFromSuperview];
        alert = [[FCAlertView alloc] init];
        alert.colorScheme = [UIColor blackColor];
        [alert makeAlertTypeCaution];
        [alert showAlertInView:self
                     withTitle:@"Smart Light"
                  withSubtitle:@"Something went wrong. Please try again later."
               withCustomImage:[UIImage imageNamed:@"logo.png"]
           withDoneButtonTitle:nil
                    andButtons:nil];
    }
}
-(void)onLongPress:(UILongPressGestureRecognizer *)pGesture
{
    CGPoint touchPoint = [pGesture locationInView:tblView];
    NSIndexPath* indexPath = [tblView indexPathForRowAtPoint:touchPoint];
    if (indexPath == nil)
    {
        return;
    }
    if ([[[BLEManager sharedManager] nonConnectArr] count] == 0)
    {
        return;
    }
    else
    {
        if (globalPeripheral.state == CBPeripheralStateConnected)
        {
            if (pGesture.state == UIGestureRecognizerStateRecognized)
            {
                //Do something to tell the user!
            }
            if (pGesture.state == UIGestureRecognizerStateBegan)
            {
                CGPoint touchPoint = [pGesture locationInView:tblView];
                NSIndexPath* indexPath = [tblView indexPathForRowAtPoint:touchPoint];
                if (indexPath != nil)
                {
                    //Handle the long press on row
                    
                    NSMutableArray * arrayDevices = [[NSMutableArray alloc] init];
                    arrayDevices =[[BLEManager sharedManager] nonConnectArr];
                    
                    if ([arrayDevices count]>indexPath.row)
                    {
                        CBPeripheral * p = [[arrayDevices objectAtIndex:indexPath.row] objectForKey:@"peripheral"];
                        myPeripheral = p;
                        NSString * manuStr = [[arrayDevices objectAtIndex:indexPath.row] objectForKey:@"Manufac"];
                        manuStr = [manuStr stringByReplacingOccurrencesOfString:@" " withString:@""];
                        manuStr = [manuStr stringByReplacingOccurrencesOfString:@">" withString:@""];
                        manuStr = [manuStr stringByReplacingOccurrencesOfString:@"<" withString:@""];
                        
                        if ([manuStr length]>=26)
                        {
                            NSRange RANGEKP = NSMakeRange(18, 4);
                            NSString * strAddedd = [manuStr substringWithRange:RANGEKP];
                            if ([strAddedd isEqualToString:@"1700"])
                            {
                                NSRange range71 = NSMakeRange(6, 4);
                                NSString * strHexDeviceID = [manuStr substringWithRange:range71];
                                
                                if ([strHexDeviceID length]>=4)
                                {
                                    NSString * str1 = [strHexDeviceID substringWithRange:NSMakeRange(0, 2)];
                                    NSString * str2 = [strHexDeviceID substringWithRange:NSMakeRange(2, 2)];
                                    
                                    NSString * strConverted = [NSString stringWithFormat:@"%@%@",str2,str1];
                                    unsigned result = 0;
                                    NSScanner *scanner = [NSScanner scannerWithString:strConverted];
                                    [scanner scanHexInt:&result];
                                    newDeviceID = [NSString stringWithFormat:@"%u",result];
                                    
                                    if ([manuStr length]>37)
                                    {
                                        range71 = NSMakeRange([manuStr length]-4, 4);
                                        NSString * strType = [manuStr substringWithRange:range71];
                                        [self getDeviceTypes:strType];
                                    }
                                    else
                                    {
                                        [self getDeviceTypes:@"0100"];
                                    }
                                    [self SengCheckDeviceMethod:manuStr withDeviceName:p.name];
                                }
                            }
                            else
                            {
                                if (globalPeripheral.state == CBPeripheralStateConnected)
                                {
                                    [self SengCheckDeviceMethod:manuStr withDeviceName:p.name];
                                }
                                else
                                {
                                    [APP_DELEGATE endHudProcess];
//                                    [self ConnectionValidationPopup];
                                }
                            }
                        }
                    }
                }
            }
        }
        else
        {
            [APP_DELEGATE endHudProcess];
            [self ConnectionValidationPopup];
        }
    }
   
}
#pragma mark - MEScrollToTopDelegate Methods

- (void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    [topPullToRefreshManager tableViewScrolled];
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView.contentOffset.y >=360.0f)
    {
    }
    else
        [topPullToRefreshManager tableViewReleased];
}
- (void)pullToRefreshTriggered:(MNMPullToRefreshManager *)manager
{
    [self refreshBtnClick];
    [self performSelector:@selector(stoprefresh) withObject:nil afterDelay:1.5];

   /* if ([IS_USER_SKIPPED isEqualToString:@"NO"])
    {
        //[lblAccName setText:[self checkforValidString:[[NSUserDefaults standardUserDefaults] valueForKey:@"CURRENT_USER_NAME"]]];
        
        if ([APP_DELEGATE isNetworkreachable])
        {
            if (isForGroup)
            {
                
            }
            else
            {
                [self refreshBtnClick];
                [self performSelector:@selector(stoprefresh) withObject:nil afterDelay:1.5];
            }
        }
    }
    else
    {
        [topPullToRefreshManager tableViewReloadFinishedAnimated:NO];
    }*/
    
}
-(void)stoprefresh
{
    [topPullToRefreshManager tableViewReloadFinishedAnimated:NO];
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
 ble_address=000232ac6606&device_id=4065&device_name=Smart Light 1&device_type=1&hex_device_id=e10f&user_id=2
 
 <0a00320c 057e1128 235d0036 00>;
 0a0032ca 04430528 235d0036 00>
*/

//kCBAdvDataManufacturerData = <0a003206 00942628 235d0036 00>;


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
/*
 platform :ios, ‘8.0’

 target ‘SmartLightApp’ do
 pod "Color-Picker-for-iOS", "~> 2.0"
 pod 'MMParallaxCell'
 pod 'DCAnimationKit'
 pod "SAMultisectorControl"
 pod 'lottie-ios'
 pod 'Firebase/Core'
 pod 'Firebase/Auth'
 pod 'Firebase/Crashlytics'
 pod 'UIFloatLabelTextField'
 end
 **/
