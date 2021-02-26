//
//  SocketWiFiSetupVC.m
//  SmartLightApp
//
//  Created by Vithamas Technologies on 25/01/21.
//  Copyright © 2021 Kalpesh Panchasara. All rights reserved.
//

#import "SocketWiFiSetupVC.h"
#import "SwitchesCell.h"
#import "HomeCell.h"
@interface SocketWiFiSetupVC ()<UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate,FCAlertViewDelegate,URLManagerDelegate,BLEServiceDelegate>

@end

@implementation SocketWiFiSetupVC
{
    UITableView * tblSSIDList,*tblSettingList;
    UITextField *txtRouterPassword;
    int globalStatusHeight;
    UIView * viewForTxtBg,*viewTxtfld,*viewSSIDback,*viewSSIDList;
    NSTimer * connectionTimer,* WifiScanTimer;
    NSMutableArray *arrayWifiavl;
    FCAlertView *alert;
    BOOL isWifiListFound, isWifiWritePasswordResponded,isCurrentDeviceWIFIConfigured;
    NSInteger selectedWifiIndex;
    NSString * strSSID;
    NSMutableDictionary * serverDict;
    UILabel * lblWifiConfigure;
    UIButton * btnConfigWifi;
    UIImageView * imgWifiState;
    
}
@synthesize strSavedID,peripheralPss;
- (void)viewDidLoad
{
    globalStatusHeight = 20;
    if (IS_IPHONE_4 || IS_IPHONE_5)
    {
        textSizes = 14;
    }
    if (IS_IPHONE_X)
    {
        globalStatusHeight = 44;
    }
    
    self.navigationController.navigationBarHidden = true;
    
    UIImageView * imgBack = [[UIImageView alloc] init];
    imgBack.contentMode = UIViewContentModeScaleAspectFit;
    imgBack.frame = CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT);
    imgBack.image = [UIImage imageNamed:[[NSUserDefaults standardUserDefaults]valueForKey:@"globalBackGroundImage"]];
    imgBack.userInteractionEnabled = YES;
    [self.view addSubview:imgBack];
    
    [self setNavigationViewFrames];
    [[BLEService sharedInstance] setDelegate:self];

    [super viewDidLoad];
    // Do any additional setup after loading the view.
}
#pragma mark - Set Frames
-(void)setNavigationViewFrames
{
    int yy = 44;
    if (IS_IPHONE_X)
    {
        yy = 44;
    }
    
    UIView * viewHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, yy+globalStatusHeight)];
    [viewHeader setBackgroundColor:[UIColor clearColor]];
    [self.view addSubview:viewHeader];
    
    
    UILabel * lblLine = [[UILabel alloc] initWithFrame:CGRectMake(0, yy + globalStatusHeight-1, DEVICE_WIDTH,1)];
    [lblLine setBackgroundColor:[UIColor lightGrayColor]];
    [viewHeader addSubview:lblLine];
    
    UILabel * lblTitle = [[UILabel alloc] initWithFrame:CGRectMake(50, globalStatusHeight, DEVICE_WIDTH-100, yy)];
    [lblTitle setBackgroundColor:[UIColor clearColor]];
    [lblTitle setText:@"Setting"];
    [lblTitle setTextAlignment:NSTextAlignmentCenter];
    [lblTitle setFont:[UIFont fontWithName:CGRegular size:textSizes+2]];
    [lblTitle setTextColor:[UIColor whiteColor]];
    [viewHeader addSubview:lblTitle];
    
    UIImageView * backImg = [[UIImageView alloc] initWithFrame:CGRectMake(15, 12+20, 12, 20)];
    [backImg setImage:[UIImage imageNamed:@"back_icon.png"]];
    [backImg setContentMode:UIViewContentModeScaleAspectFit];
    backImg.backgroundColor = [UIColor clearColor];
    [viewHeader addSubview:backImg];
    
    UIButton * btnBack = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnBack addTarget:self action:@selector(btnBackClick) forControlEvents:UIControlEventTouchUpInside];
    btnBack.frame = CGRectMake(0, 0, 70, 64);
    btnBack.backgroundColor = [UIColor clearColor];
    [viewHeader addSubview:btnBack];
    
    imgWifiState = [[UIImageView alloc] initWithFrame:CGRectMake(DEVICE_WIDTH/2-40, globalStatusHeight+100, 40, 40)];
    [imgWifiState setImage:[UIImage imageNamed:@"tick.png"]];
    [imgWifiState setContentMode:UIViewContentModeScaleAspectFit];
    imgWifiState.backgroundColor = [UIColor clearColor];
    imgWifiState.layer.cornerRadius = 20;
    imgWifiState.backgroundColor = UIColor.redColor;
    [self.view addSubview:imgWifiState];
    
    
    lblWifiConfigure = [[UILabel alloc] initWithFrame:CGRectMake(0, globalStatusHeight+150, DEVICE_WIDTH, yy)];
    [lblWifiConfigure setBackgroundColor:[UIColor clearColor]];
    [lblWifiConfigure setText:@"Wi-Fi not configured"];
    [lblWifiConfigure setTextAlignment:NSTextAlignmentCenter];
    [lblWifiConfigure setFont:[UIFont fontWithName:CGRegular size:textSizes+2]];
    [lblWifiConfigure setTextColor:[UIColor whiteColor]];
    lblWifiConfigure.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:lblWifiConfigure];
    
    btnConfigWifi  = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnConfigWifi addTarget:self action:@selector(btnWifiClick) forControlEvents:UIControlEventTouchUpInside];
    btnConfigWifi.frame = CGRectMake(50, globalStatusHeight+250, DEVICE_WIDTH-100, 60);
    btnConfigWifi.backgroundColor = [UIColor blueColor];
//    btnConfigWifi.alpha = 0.6;
    [btnConfigWifi setTitle:@"Configure wi-fi" forState:UIControlStateNormal];
    btnConfigWifi.layer.cornerRadius = 5;
    [self.view addSubview:btnConfigWifi];
    
    
    tblSettingList = [[UITableView alloc] initWithFrame:CGRectMake(0, yy+globalStatusHeight, DEVICE_WIDTH, DEVICE_HEIGHT-yy-globalStatusHeight)];
    tblSettingList.delegate = self;
    tblSettingList.dataSource= self;
    tblSettingList.separatorStyle = UITableViewCellSelectionStyleNone;
    [tblSettingList setShowsVerticalScrollIndicator:NO];
    tblSettingList.backgroundColor = [UIColor clearColor];
    tblSettingList.separatorStyle = UITableViewCellSeparatorStyleNone;
    tblSettingList.separatorColor = [UIColor darkGrayColor];
    tblSettingList.hidden = true;
    [self.view addSubview:tblSettingList];
    
}
#pragma mark- Tableview Delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == tblSettingList)
    {
        return 1;
    }
    else
    {
        if (arrayWifiavl.count >0)
        {
            return arrayWifiavl.count;
        }
    }
    return 0;
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == tblSettingList)
    {
        return 70;
    }
    else if (tableView == tblSSIDList)
    {
        return 40;
    }
    return 0;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellReuseIdentifier = @"cellIdentifier";
    HomeCell *cell = [tableView dequeueReusableCellWithIdentifier:cellReuseIdentifier];
    if (cell == nil)
    {
        cell = [[HomeCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellReuseIdentifier];
    }

    if (tableView == tblSettingList)
    {
        cell.lblDeviceName.frame = CGRectMake(5, 0, DEVICE_WIDTH-50, 50);
        cell.imgSwitch.frame = CGRectMake(DEVICE_WIDTH-30, 15, 15, 20);

        cell.lblDeviceName.text = @"Wi-Fi setting";
        cell.lblLine.hidden = false;
        cell.lblConnect.hidden = true;
        cell.lblBack.hidden = false;
        cell.lblAddress.hidden = true;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.imgSwitch.hidden = true;
        [cell.imgSwitch setImage:[UIImage imageNamed:@"right_gray_arrow.png"]];
    }
    else if (tableView == tblSSIDList)
    {
        cell.lblConnect.hidden = true;
        cell.lblBack.hidden = true;
        cell.lblDeviceName.textColor = UIColor.blackColor;
        cell.lblDeviceName.text = [[arrayWifiavl objectAtIndex:indexPath.row] valueForKey:@"SSIDdata"];//;
        cell.lblAddress.hidden = true; //[[arrayWifiList objectAtIndex:indexPath.row] valueForKey:@"SSIDdata"];//@"VithamasTech";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return cell;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == tblSettingList)
    {
        if (indexPath.row == 0)
        {
    //        if ([[self checkforValidString:strSSId] isEqual:@""])
            {
//                [self  AskforWifiConfiguration];
            }
    //        else
            {
    //            [self AskforWifiConfigurationDelete];
            }
        }

    }
    else if (tableView == tblSSIDList)
    {
        selectedWifiIndex = indexPath.row;
        NSString * strSSID = @"";
        strSSID = [[arrayWifiavl objectAtIndex:indexPath.row] valueForKey:@"SSIDdata"];
        [self OpenWIFIViewtoSetPassword:strSSID];

        [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self-> viewSSIDList.frame = CGRectMake(20, DEVICE_HEIGHT, DEVICE_WIDTH-40, 300);}
                        completion:(^(BOOL finished){
            [self-> viewSSIDback removeFromSuperview];})];
    }
}
#pragma mark- Setup For testFielld
-(void)OpenWIFIViewtoSetPassword:(NSString *)strWIFIname
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
    
        [APP_DELEGATE endHudProcess];
        [self-> viewTxtfld removeFromSuperview];

        self->viewForTxtBg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT)];
        self->viewForTxtBg .backgroundColor = UIColor.blackColor;
        self->viewForTxtBg.alpha = 0.5;
        [self.view addSubview:self->viewForTxtBg];
    
        self->viewTxtfld = [[UIView alloc] initWithFrame:CGRectMake(20, DEVICE_HEIGHT, DEVICE_WIDTH-40, 250)];
        self->viewTxtfld .backgroundColor = [UIColor colorWithRed:245.0/255 green:1 blue:1 alpha:1]; //
        self->viewTxtfld.layer.cornerRadius = 6;
//        self->viewTxtfld.alpha = 1;
//        self->viewTxtfld.layer.borderColor = UIColor.whiteColor.CGColor;
//        self->viewTxtfld.layer.borderWidth = 0.5;
        self->viewTxtfld.clipsToBounds = true;
        [self.view addSubview:self->viewTxtfld];
    
        int yy = 00;
        UILabel * lblHint = [[UILabel alloc] initWithFrame:CGRectMake(5, 10, self->viewTxtfld.frame.size.width-10, 40)];
        lblHint.text = @"Please Enter password to connect Device with Wi-Fi.";
        lblHint.textColor = UIColor.blackColor;
//    lblHint.backgroundColor = UIColor.lightGrayColor;
        lblHint.textAlignment = NSTextAlignmentCenter;
        lblHint.numberOfLines = 0;
        lblHint.font = [UIFont fontWithName:CGRegular size:textSizes];
        [self->viewTxtfld addSubview:lblHint];
    
    
        yy = yy+60;
        UILabel * lblRouterName = [[UILabel alloc] initWithFrame:CGRectMake(10, yy, self->viewTxtfld.frame.size.width-20, 60)];
        lblRouterName.textColor= UIColor.blackColor;
        lblRouterName.textAlignment = NSTextAlignmentCenter;
        lblRouterName.numberOfLines = 0;
        lblRouterName.font = [UIFont fontWithName:CGRegular size:textSizes+1];
        lblRouterName.text = [NSString stringWithFormat:@"Connected Wi-Fi \n%@",strWIFIname];
        [self->viewTxtfld addSubview:lblRouterName];
     
        yy = yy+80;
        self->txtRouterPassword = [[UITextField alloc] initWithFrame:CGRectMake(10, yy, self->viewTxtfld.frame.size.width-20, 50)];
        [self setTextfieldProperties:self->txtRouterPassword withPlaceHolderText:@" Enter Wi-Fi Password" withtextSizes:textSizes];
        self->txtRouterPassword.returnKeyType = UIReturnKeyDone;
        self->txtRouterPassword.textColor = UIColor.whiteColor;
        self->txtRouterPassword.backgroundColor = UIColor.blackColor;
        self->txtRouterPassword.alpha = 0.7;
        [self->viewTxtfld addSubview:self->txtRouterPassword];
    
        UIButton *  btnNotNow = [[UIButton alloc]init];
        btnNotNow.frame = CGRectMake(0, self->viewTxtfld.frame.size.height-50, self->viewTxtfld.frame.size.width/2-5, 50);
        [btnNotNow addTarget:self action:@selector(btnNotNowClick) forControlEvents:UIControlEventTouchUpInside];
        [btnNotNow setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        btnNotNow.backgroundColor = [UIColor colorWithRed:1 green:155.0/255 blue:0 alpha:1];//UIColor.yellowColor;
//        btnNotNow.alpha = 0.7;
        [btnNotNow setTitle:@"Not now" forState:normal];
        [btnNotNow setTitleColor:UIColor.whiteColor forState:normal];
        btnNotNow.titleLabel.font = [UIFont fontWithName:CGRegular size:textSizes+2];
        [self->viewTxtfld addSubview:btnNotNow];
    
        
        UIButton *  btnSave = [[UIButton alloc]init];
        btnSave.frame = CGRectMake(self->viewTxtfld.frame.size.width/2, self->viewTxtfld.frame.size.height-50, self->viewTxtfld.frame.size.width/2, 50);
        [btnSave addTarget:self action:@selector(btnSaveWIFIClick) forControlEvents:UIControlEventTouchUpInside];
        [btnSave setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btnSave.backgroundColor = [UIColor colorWithRed:1 green:155.0/255 blue:0 alpha:1];//UIColor.yellowColor;
        [btnSave setTitle:@"Save" forState:normal];
//        btnSave.alpha = 0.7;
        [btnSave setTitleColor:UIColor.whiteColor forState:normal];
        btnSave.titleLabel.font = [UIFont fontWithName:CGRegular size:textSizes+2];
        [self->viewTxtfld addSubview:btnSave];
    
        [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            self->viewTxtfld.frame = CGRectMake(20, (DEVICE_HEIGHT-250)/2, DEVICE_WIDTH-40, 250);
        }
            completion:NULL];
        });
}
#pragma mark-TextField method
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
 if (textField == txtRouterPassword)
 {
     [txtRouterPassword resignFirstResponder];
 }
    return textField;
}
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
        self->viewTxtfld.frame = CGRectMake(20, (DEVICE_HEIGHT-250)/2-100, DEVICE_WIDTH-40, 250);
}
- (void)textFieldDidEndEditing:(UITextField *)textField
{
        self->viewTxtfld.frame = CGRectMake(20, (DEVICE_HEIGHT-250)/2, DEVICE_WIDTH-40, 250);
}
#pragma mark- ALL BUttons Deligate
-(void)btnBackClick
{
    [self.navigationController popViewControllerAnimated:true];
}
-(void)btnNotNowClick
{
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^
     {
    self-> viewTxtfld.frame = CGRectMake(20, DEVICE_HEIGHT, DEVICE_WIDTH-40, 250);
     }
        completion:(^(BOOL finished)
      {
        [self-> viewForTxtBg removeFromSuperview];
        [self AlertViewFCTypeCautionCheck:@"Now you can only Control through Bluetooth"];

    })];
}
-(void)btnSaveWIFIClick
{
  if ([txtRouterPassword.text isEqual:@""])
    {
        [self AlertViewFCTypeCautionCheck:@"Please enter Wi-Fi password"];
    }
    else
    {
        [APP_DELEGATE startHudProcess:@"Processing..."];
        // MQTT request to device here 13 for ssid  14 for password and IP = @"13.57.255.95"
        if ([APP_DELEGATE isNetworkreachable]) 
        {
            isWifiWritePasswordResponded = NO;
            [connectionTimer invalidate];
            connectionTimer = nil;
            connectionTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(ConnectWifiTimeout) userInfo:nil  repeats:NO];
            
            NSString * strIndex = [[arrayWifiavl objectAtIndex:selectedWifiIndex] valueForKey:@"Index"];
            NSInteger intPacket = [strIndex integerValue];
            NSData * dataPacket = [[NSData alloc] initWithBytes:&intPacket length:1];
            [[BLEService sharedInstance] WriteSocketData:dataPacket withOpcode:@"13" withLength:@"01" withPeripheral:globalSocketPeripheral];


            [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self-> viewForTxtBg.frame = CGRectMake(20, DEVICE_HEIGHT, DEVICE_WIDTH-40, 250);
            }completion:(^(BOOL finished){
                [self-> viewTxtfld removeFromSuperview];
            })];
        }
        else
        {
            [self AlertViewFCTypeCautionCheck:@"Please connect to the internet."];
        }
    }
}
-(void)btnCancelClick
{
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^
     {
    self-> viewSSIDList.frame = CGRectMake(20, DEVICE_HEIGHT, DEVICE_WIDTH-40, 300);
     }
        completion:(^(BOOL finished)
      {
        [self-> viewSSIDback removeFromSuperview];
    })];
}
-(void)btnWifiClick
{
    [self  AskforWifiConfiguration];
}
#pragma mark- Setup for WIFI List the Showing Available SSID list
-(void)SetupForShowWifiSSIList
{
    dispatch_async(dispatch_get_main_queue(), ^(void){

        [APP_DELEGATE endHudProcess];
        [self->viewSSIDback removeFromSuperview];
        self->viewSSIDback = [[UIView alloc] init];
        self->viewSSIDback.frame = CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT);
        self->viewSSIDback .backgroundColor = UIColor.blackColor;
        self->viewSSIDback.alpha = 0.5;
        [self.view addSubview:self->viewSSIDback];
        
        UIImageView * imgBack = [[UIImageView alloc] init];
        imgBack.contentMode = UIViewContentModeScaleAspectFit;
        imgBack.frame = CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT);
        imgBack.image = [UIImage imageNamed:[[NSUserDefaults standardUserDefaults]valueForKey:@"globalBackGroundImage"]];
        imgBack.userInteractionEnabled = YES;
//        [self->viewSSIDback addSubview:imgBack];
        
        self->viewSSIDList = [[UIView alloc] initWithFrame:CGRectMake(20, DEVICE_HEIGHT, DEVICE_WIDTH-40, 300)];
        self->viewSSIDList.backgroundColor = UIColor.whiteColor;//[UIColor colorWithRed:1 green:1 blue:1 alpha:1]; // white
        self->viewSSIDList.layer.cornerRadius = 6;
        self->viewSSIDList.alpha = 1;
        self->viewSSIDList.clipsToBounds = true;
       [self.view addSubview:self->viewSSIDList];
    
        self->tblSSIDList = [[UITableView alloc] initWithFrame:CGRectMake(5, 5, self->viewSSIDList.frame.size.width-10, self->viewSSIDList.frame.size.height-50)];
        self->tblSSIDList.backgroundColor = UIColor.clearColor;
        self->tblSSIDList.delegate = self;
        self->tblSSIDList.dataSource = self;
        [self->viewSSIDList addSubview:self->tblSSIDList];
    
        UIButton *  btnCancel = [[UIButton alloc]init];
        btnCancel.frame = CGRectMake(5, self->viewSSIDList.frame.size.height-50, self->viewSSIDList.frame.size.width-10, 45);
        [btnCancel addTarget:self action:@selector(btnCancelClick) forControlEvents:UIControlEventTouchUpInside];
        [btnCancel setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btnCancel.backgroundColor = [UIColor colorWithRed:1 green:155.0/255 blue:0 alpha:1];//UIColor.blackColor;
        [btnCancel setTitle:@"Cancel" forState:normal];
        [btnCancel setTitleColor:UIColor.whiteColor forState:normal];
        btnCancel.titleLabel.font = [UIFont fontWithName:CGRegular size:textSizes+2];
        btnCancel.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self->viewSSIDList addSubview:btnCancel];
    
        [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            self->viewSSIDList.frame = CGRectMake(20, (DEVICE_HEIGHT-300)/2, DEVICE_WIDTH-40, 300);
        }
            completion:NULL];
});
}
-(void)ConnectWifiTimeout
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [APP_DELEGATE endHudProcess];
        
        if (isWifiWritePasswordResponded == NO)
        {
            [self AlertViewFCTypeCautionCheck:@"Something went wrong. Please try again!"];
        }
        isWifiWritePasswordResponded = NO;
    });
}
-(void)AskforWifiConfiguration
{
    if (peripheralPss.state == CBPeripheralStateConnected)
    {
        [alert removeFromSuperview];
        alert = [[FCAlertView alloc] init];
        alert.colorScheme = [UIColor blackColor];
        [alert makeAlertTypeCaution];
        alert.tag = 555;
        alert.delegate = self;
        [alert addButton:@"Yes" withActionBlock:
         ^{
            [APP_DELEGATE startHudProcess:@"Cheking availble Wi-Fi..."];
            NSInteger intPacket = [@"0" integerValue];
            NSData * dataPacket = [[NSData alloc] initWithBytes:&intPacket length:1];
            [[BLEService sharedInstance] WriteSocketData:dataPacket withOpcode:@"18" withLength:@"00" withPeripheral:globalSocketPeripheral];
    //        isWifiListFound = NO;
            WifiScanTimer = nil;
            WifiScanTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(wifiScanTimeoutMethod) userInfo:nil repeats:NO];
        }];
        [alert showAlertInView:self
                     withTitle:@"Smart socket"
                  withSubtitle:@"Do you want to configure Wi-Fi ?"
               withCustomImage:[UIImage imageNamed:@"Subsea White 180.png"]
           withDoneButtonTitle:@"No" andButtons:nil];
    }
    else
    {
        [self AlertViewFCTypeCautionCheck:@"Device not connected to the bluetooth."];
    }
}
-(void)AskforWifiConfigurationDelete
{
    [alert removeFromSuperview];
    alert = [[FCAlertView alloc] init];
    alert.colorScheme = [UIColor blackColor];
    [alert makeAlertTypeCaution];
    alert.delegate = self;
    [alert addButton:@"Yes" withActionBlock:
     ^{
        [APP_DELEGATE startHudProcess:@"Removing..."];
        NSInteger intPacket = [@"0" integerValue];
        NSData * dataPacket = [[NSData alloc] initWithBytes:&intPacket length:1];
        
        [[BLEService sharedInstance] WriteSocketData:dataPacket withOpcode:@"26" withLength:@"00" withPeripheral:globalSocketPeripheral];
    }];
    [alert showAlertInView:self
                 withTitle:@"Smart socket"
              withSubtitle:@"Do you wnat to remove Wi-Fi ?"
           withCustomImage:[UIImage imageNamed:@"Subsea White 180.png"]
       withDoneButtonTitle:@"No" andButtons:nil];
}
-(void)wifiScanTimeoutMethod
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [APP_DELEGATE endHudProcess];
        if (isWifiListFound == NO)
        {
            [self AlertViewFCTypeCautionCheck:@"No Wi-Fi available nearby !"];
        }
        
        isWifiListFound = NO;
    });
}
-(void)FoundNumberofWIFITOsetting:(NSMutableArray *)arrayWifiList
{
    isWifiListFound = YES;
    [WifiScanTimer invalidate];
    WifiScanTimer = nil;

    arrayWifiavl = [[NSMutableArray alloc] init];
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
    if (arrayWifiList.count > 0)
    {
        self->arrayWifiavl = arrayWifiList;
        [APP_DELEGATE endHudProcess];
        [self SetupForShowWifiSSIList];
        [self->tblSSIDList reloadData];
        NSLog(@"Connected WI fi ===>>%@",arrayWifiList);
    }
    else
    {
        [APP_DELEGATE endHudProcess];
    }
    });
}
-(void)WifiPasswordAcknowledgement:(NSString *)strStatus
{
    isWifiWritePasswordResponded = YES;
    if ([strStatus isEqualToString:@"01"])
    {
//        NSString * strUpdate = [NSString stringWithFormat:@"update Device_Table set wifi_configured = '1' where id = '%@'",strSavedTableID];
//        [[DataBaseManager dataBaseManager] execute:strUpdate];

        if (![IS_USER_SKIPPED isEqualToString:@"YES"])
        {
            [self UpdateWifiConfigurationStatustoServer];
        }
        else
        {
            [APP_DELEGATE endHudProcess];
            FCAlertView *alert = [[FCAlertView alloc] init];
            [alert makeAlertTypeSuccess];
            alert.tag = 555;
            alert.delegate = self;
            alert.firstButtonCustomFont = [UIFont fontWithName:CGRegular size:textSizes];
            [alert showAlertWithTitle:@"Vithamas" withSubtitle:@"Wifi configured successfully." withCustomImage:[UIImage imageNamed:@"alert-round.png"] withDoneButtonTitle:@"OK" andButtons:nil];
        }
    }
    else
    {
        [APP_DELEGATE endHudProcess];
        FCAlertView *alert = [[FCAlertView alloc] init];
        [alert makeAlertTypeCaution];
        alert.firstButtonCustomFont = [UIFont fontWithName:CGRegular size:textSizes];
        [alert showAlertWithTitle:@"Vithamas" withSubtitle:@"Something went wrong. Please try again later." withCustomImage:[UIImage imageNamed:@"alert-round.png"] withDoneButtonTitle:@"OK" andButtons:nil];
    }
}
-(void)NoWIIFoundNearby
{
    isWifiListFound = YES;
    [WifiScanTimer invalidate];
    WifiScanTimer = nil;
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [self AlertViewFCTypeCautionCheck:@"No Wi-Fi available nearby !"];
    });
}
-(void)FoundNumberofWIFI:(NSMutableArray *)arrayWifiList
{
    isWifiListFound = YES;
    [WifiScanTimer invalidate];
    WifiScanTimer = nil;

    arrayWifiavl = [[NSMutableArray alloc] init];
    dispatch_async(dispatch_get_main_queue(), ^(void){
    if (arrayWifiList.count > 0)
    {
        self->arrayWifiavl = arrayWifiList;
        [APP_DELEGATE endHudProcess];
        [self SetupForShowWifiSSIList];
        [self->tblSSIDList reloadData];
        NSLog(@"Connected WI fi ===>>%@",arrayWifiList);
    }
    else
    {
        [APP_DELEGATE endHudProcess];
//        [self AlertViewFCTypeCautionCheck:@"There is no Wi-Fi nearby!"];
    }
    });
}
-(void)UpdateWifiConfigurationStatustoServer
{
    if ([APP_DELEGATE isNetworkreachable])
    {
     serverDict = [[NSMutableDictionary alloc] init];
        
        if ([serverDict count] >= 11)
        {
            [serverDict setValue:@"1" forKey:@"is_update"];
            [serverDict setValue:@"1" forKey:@"wifi_configured"];

            URLManager *manager = [[URLManager alloc] init];
            manager.commandName = @"UpdateDevice";
            manager.delegate = self;
            NSString *strServerUrl = @"http://vithamastech.com/smartlight/api/save_device";
            [manager urlCall:strServerUrl withParameters:serverDict];
        }
    }
}
#pragma mark- BLEService Delegate Methods
-(void)RecievedWifiConfiguredStatus:(NSString *)strStatus
{
    //if 0000 - Wifi Not Available & No Interenet
    //if 0100 - Wifi Available & No Internet
    //if 0101 - Wifi Availavle & MQTT Not Connected
    //if 0102 - Wifi Available & MQTT Connected
    isCurrentDeviceWIFIConfigured = YES;
//    NSLog(@"showAlertforWIFIStatus ====>%@",strStatus);
    if ([strStatus isEqualToString:@"0000"])
    {
        isCurrentDeviceWIFIConfigured = NO;
    }
    else if ([strStatus isEqualToString:@"0100"])
    {
    }
    else if ([strStatus isEqualToString:@"0101"])
    {
    }
    else if ([strStatus isEqualToString:@"0102"])
    {
    }
}
-(void)WifiSSIDIndexAcknowlegement:(NSString *)strStatus
{
    NSString * strPassword  = txtRouterPassword.text;
    [[BLEService sharedInstance] WriteWifiPassword:strPassword];
}
#pragma mark-textField
-(void)setTextfieldProperties:(UITextField *)txtfld withPlaceHolderText:(NSString *)strText withtextSizes:(int)textSizes
{
    txtfld.delegate = self;
    txtfld.attributedPlaceholder = [[NSAttributedString alloc] initWithString:strText attributes:@{NSForegroundColorAttributeName: [UIColor darkGrayColor],NSFontAttributeName: [UIFont fontWithName:CGRegular size:textSizes]}];
    txtfld.textAlignment = NSTextAlignmentLeft;
    txtfld.textColor = [UIColor blackColor];
    txtfld.backgroundColor= UIColor.whiteColor;
//    txtfld.autocorrectionType = UITextAutocorrectionTypeNo;
    txtfld.layer.cornerRadius = 6;
    txtfld.font = [UIFont boldSystemFontOfSize:textSizes];
    txtfld.font = [UIFont fontWithName:CGRegular size:textSizes];
    txtfld.clipsToBounds = true;
    txtfld.delegate = self;
}
-(void)AlertViewFCTypeCautionCheck:(NSString *)strMsg
    {
        FCAlertView *alert = [[FCAlertView alloc] init];
        alert.colorScheme = [UIColor blackColor];
        [alert makeAlertTypeCaution];
        [alert showAlertInView:self
                     withTitle:@"Vithamas"
                  withSubtitle:strMsg
               withCustomImage:[UIImage imageNamed:@"logo.png"]
           withDoneButtonTitle:nil
                    andButtons:nil];
    }
-(void)AlertViewFCTypeSuccess:(NSString *)strPopup
{
        FCAlertView *alert = [[FCAlertView alloc] init];
        alert.colorScheme = [UIColor blackColor];
        [alert makeAlertTypeSuccess];
        [alert showAlertInView:self
                     withTitle:@"Vithamas"
                  withSubtitle:strPopup
               withCustomImage:[UIImage imageNamed:@"logo.png"]
           withDoneButtonTitle:nil
                    andButtons:nil];
}
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
@end
