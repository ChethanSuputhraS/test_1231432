//
//  SocketDetailVC.m
//  SmartLightApp
//
//  Created by Kalpesh Panchasara on 06/01/21.
//  Copyright © 2021 Kalpesh Panchasara. All rights reserved.
//

#import "SocketDetailVC.h"
#import "HomeCell.h"
#import "SocketAlarmVC.h"
#import "BLEManager.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface SocketDetailVC ()<UITableViewDelegate,UITableViewDataSource,UIPickerViewDelegate,UIPickerViewDataSource,UITextFieldDelegate,CBCentralManagerDelegate, CocoaMQTTDelegate>
{
    UIView *viewBGPicker,*pickerSetting;
    UIDatePicker * datePicker;
    NSString *selectedTime;
    UIButton * btnCancel;
    NSString * selectedDate;
    UIView *  viewForTxtBg,*viewTxtfld;
    UITextField *txtDeviceName,*txtRouterName,*txtRouterPassword;
    UIImageView *imgNotConnected, *imgNotWifiConnected;
    NSString * strSSID;
    CBCentralManager * _centralManager;
    NSString * strAllSwSatate;
    NSMutableDictionary *dictFromHomeSwState;
    NSMutableArray * arryDevices, * arrAlarmIdsofDevices;
    
    
}
@end

@implementation SocketDetailVC
@synthesize dictFromHomeSwState1, classMqttObj, deviceDetail;
@synthesize isMQTTselect,classPeripheral ,strMacAddress,strWifiConnect;

- (void)viewDidLoad
{
    arrAlarmIdsofDevices = [[NSMutableArray alloc] init];
    if ([[deviceDetail valueForKey:@"wifi_configured"] isEqualToString:@"1"])
    {
        if (classMqttObj == nil)
        {
            [self ConnecttoMQTTSocketServer];
        }
        else
        {
//            NSString * publishTopic = [NSString stringWithFormat:@"/vps/device/%@",strMacAddress];
//            UInt16 subTop = [classMqttObj subscribe:publishTopic qos:2];
//            NSLog(@"MQTT subcriptionTopic===>>>%hu",subTop);
        }
    }
    strMacAddress = [[deviceDetail valueForKey:@"ble_address"] uppercaseString];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DeviceDidConnectNotificationSocket" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DeviceDidDisConnectNotificationSocket" object:nil];
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(DeviceDidConnectNotification:) name:@"DeviceDidConnectNotificationSocket" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(DeviceDidDisConnectNotification:) name:@"DeviceDidDisConnectNotificationSocket" object:nil];

    
    if (classPeripheral == nil)
    {
//        [APP_DELEGATE startHudProcess:@"Connecting..."];
        NSMutableArray * arrCnt = [[NSMutableArray alloc] init];
        arrCnt = [[BLEManager sharedManager] arrBLESocketDevices];
        for (int i=0; i<[arrCnt count]; i++)
        {
            if ([[[arrCnt objectAtIndex:i] valueForKey:@"ble_address"] isEqualToString:strMacAddress])
            {
                CBPeripheral * tmpPerphrl = [[arrCnt objectAtIndex:i] objectForKey:@"peripheral"];
                [self setPeripheraltoCheckKeyUsage:tmpPerphrl];
                classPeripheral = tmpPerphrl;
                [[BLEManager sharedManager] connectDevice:tmpPerphrl];
                
                [self performSelector:@selector(ConnectionTimeOutCall) withObject:nil afterDelay:6];
                
                if ([[arrSocketDevices valueForKey:@"ble_address"] containsObject:[[[arrCnt objectAtIndex:i] valueForKey:@"ble_address"] uppercaseString]])
                {
                    NSInteger idxAddress = [[arrSocketDevices valueForKey:@"ble_address"] indexOfObject:[[arrCnt objectAtIndex:i] valueForKey:@"ble_address"]];
                    if (idxAddress != NSNotFound)
                    {
                        if (idxAddress < [arrSocketDevices count])
                        {
                            [[arrSocketDevices objectAtIndex:idxAddress]setObject:tmpPerphrl forKey:@"peripheral"];
                            [[arrSocketDevices objectAtIndex:idxAddress]setValue:[NSString stringWithFormat:@"%@",tmpPerphrl.identifier] forKey:@"identifier"];
                            if (tmpPerphrl.state == CBPeripheralStateConnected)
                            {
                            }
                            else
                            {
                                classPeripheral = tmpPerphrl;
                                [self setPeripheraltoCheckKeyUsage:tmpPerphrl];
                                [[BLEManager sharedManager] connectDevice:tmpPerphrl];
                            }
                        }
                    }
                }
                break;
            }
        }
    }
    else
    {
        if (classPeripheral.state != CBPeripheralStateConnected)
        {
            [self performSelector:@selector(ConnectionTimeOutCall) withObject:nil afterDelay:6];
//            [APP_DELEGATE startHudProcess:@"Connecting..."];
            [self setPeripheraltoCheckKeyUsage:classPeripheral];
            [[BLEManager sharedManager] connectDevice:classPeripheral];
        }
        else if(classPeripheral.state == CBPeripheralStateConnected)
        {
            NSInteger intPacket = [@"0" integerValue];
            NSData * dataPacket = [[NSData alloc] initWithBytes:&intPacket length:1];
            [[BLEService sharedInstance] WriteSocketData:dataPacket withOpcode:@"05" withLength:@"00" withPeripheral:classPeripheral];
            [[BLEService sharedInstance] WriteSocketData:dataPacket withOpcode:@"21" withLength:@"00" withPeripheral:classPeripheral];
//            [[BLEService sharedInstance] WriteSocketData:dataPacket withOpcode:@"22" withLength:@"00" withPeripheral:classPeripheral]; // request SSID name


        }
    }
    globalStatusHeight = 20;
    if (IS_IPHONE_4 || IS_IPHONE_5)
    {
        textSizes = 14;
    }
    if (IS_IPHONE_X)
    {
        globalStatusHeight = 44;
    }

//    [APP_DELEGATE startHudProcess:@"Loading..."];
    self.navigationController.navigationBarHidden = true;
    UIImageView * imgBack = [[UIImageView alloc] init];
    imgBack.contentMode = UIViewContentModeScaleAspectFit;
    imgBack.frame = CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT);
    imgBack.image = [UIImage imageNamed:[[NSUserDefaults standardUserDefaults]valueForKey:@"globalBackGroundImage"]];
    imgBack.userInteractionEnabled = YES;
    [self.view addSubview:imgBack];
    
    dictFromHomeSwState = [[NSMutableDictionary alloc] init];
    arryDevices = [[NSMutableArray alloc] init];

    
//    NSString * strQuery = [NSString stringWithFormat:@"Select * from Device_Table where user_id ='%@' and status = '1' group by ble_address",CURRENT_USER_ID];
//    [[DataBaseManager dataBaseManager] execute:strQuery resultsArray:arryDevices];
    
    [self setNavigationViewFrames];
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}
-(void)setPeripheraltoCheckKeyUsage:(CBPeripheral *)tmpPerphrl
{
    if ([[arrPeripheralsCheck valueForKey:@"identifier"] containsObject:tmpPerphrl.identifier])
    {
        NSInteger foundIndex = [[arrPeripheralsCheck valueForKey:@"identifier"] indexOfObject:tmpPerphrl.identifier];
        if (foundIndex != NSNotFound)
        {
            if ([arrPeripheralsCheck count] > foundIndex)
            {
                NSDictionary * dict = [NSDictionary dictionaryWithObjectsAndKeys:@"1700", @"status", tmpPerphrl.identifier,@"identifier", nil];
                [arrPeripheralsCheck replaceObjectAtIndex:foundIndex withObject:dict];
            }
        }
    }
    else
    {
        NSDictionary * dict = [NSDictionary dictionaryWithObjectsAndKeys:@"1700", @"status", tmpPerphrl.identifier,@"identifier", nil];
        [arrPeripheralsCheck addObject:dict];
    }
}
-(void)ConnectionTimeOutCall
{
    [APP_DELEGATE endHudProcess];
    if (classPeripheral.state == CBPeripheralStateConnected)
    {
        
    }
    else
    {
        //show popup something went wrong please check device is nearby or turn on.
    }
}
-(void)viewWillAppear:(BOOL)animated
{
    if (classPeripheral.state == CBPeripheralStateConnected)
    {
        NSInteger intPacket = [@"0" integerValue];
        NSData * dataPacket = [[NSData alloc] initWithBytes:&intPacket length:1];
        [[BLEService sharedInstance] WriteSocketData:dataPacket withOpcode:@"05" withLength:@"00" withPeripheral:classPeripheral];

    }

    
    [imgNotConnected removeFromSuperview];
    imgNotConnected = [[UIImageView alloc]init];
    imgNotConnected.image = [UIImage imageNamed:@"notconnect_iconWhite.png"];
    imgNotConnected.frame = CGRectMake(DEVICE_WIDTH-30, 32, 30, 22);
    imgNotConnected.contentMode = UIViewContentModeScaleAspectFit;
    imgNotConnected.layer.masksToBounds = true;
    [self.view addSubview:imgNotConnected];
    
    [imgNotWifiConnected removeFromSuperview];
    imgNotWifiConnected = [[UIImageView alloc]init];
    imgNotWifiConnected.image = [UIImage imageNamed:@"wifigreen.png"];
    imgNotWifiConnected.frame = CGRectMake(DEVICE_WIDTH-60, 32, 30, 22);
    imgNotWifiConnected.contentMode = UIViewContentModeScaleAspectFit;
    imgNotWifiConnected.layer.masksToBounds = true;
    [self.view addSubview:imgNotWifiConnected];
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

    if (IS_IPHONE_X)
    {
        imgNotConnected.frame = CGRectMake(DEVICE_WIDTH-30, 55, 30, 22);
    }
    
    if (classPeripheral.state == CBPeripheralStateConnected)
    {
        imgNotConnected.image = [UIImage imageNamed:@"Connected_icon.png"];
    }
    else
    {
        imgNotConnected.image = [UIImage imageNamed:@"notconnect_icon.png"];
    }
    
    if ([[self checkforValidString:strWifiConnect] isEqual:@"0102"])
    {
        imgNotWifiConnected.image = [UIImage imageNamed:@"wifiGreen.png"];
    }
    else
    {
        imgNotWifiConnected.image = [UIImage imageNamed:@"wifired.png"];
    }
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AuthenticationCompleted" object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AuthenticationCompleted) name:@"AuthenticationCompleted" object:nil];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        //Do what you intend to do
        imgNotConnected.image = [UIImage imageNamed:@"Connected_icon.png"];

    } else if(central.state == CBCentralManagerStatePoweredOff)
    {
        //Bluetooth is disabled. ios pops-up an alert automatically
        imgNotConnected.image = [UIImage imageNamed:@"notconnect_icon.png"];

    }
}
#pragma mark - Set Frames
-(void)setNavigationViewFrames
{
    int yy = 44;
    if (IS_IPHONE_X)
    {
        yy = 44;
    }
    
    UIImageView * imgLogo = [[UIImageView alloc] init];
    imgLogo.frame = CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT);
    imgLogo.image = [UIImage imageNamed:@"bg@1x.png"];
    imgLogo.userInteractionEnabled = YES;
    imgLogo.backgroundColor = UIColor.clearColor;
//    [self.view addSubview:imgLogo];
    
    UIView * viewHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, yy + globalStatusHeight)];
    [viewHeader setBackgroundColor:[UIColor blackColor]];
    [self.view addSubview:viewHeader];
    
    UILabel * lblLine = [[UILabel alloc] initWithFrame:CGRectMake(0, yy + globalStatusHeight-1, DEVICE_WIDTH,1)];
    [lblLine setBackgroundColor:[UIColor lightGrayColor]];
    [viewHeader addSubview:lblLine];
    
    UILabel * lblTitle = [[UILabel alloc] initWithFrame:CGRectMake(50, globalStatusHeight, DEVICE_WIDTH-100, yy)];
    [lblTitle setBackgroundColor:[UIColor clearColor]];
    [lblTitle setText:@"Switch control"];
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
    
    UIImageView * imgBacksc = [[UIImageView alloc]initWithFrame:CGRectMake(20,globalStatusHeight+yy+20, DEVICE_WIDTH-40, 60)];
    imgBacksc.image = [UIImage imageNamed:@"swsocket.png"];
    imgBacksc.backgroundColor = UIColor.clearColor;
    [self.view addSubview:imgBacksc];
    
    tblHistoryList = [[UITableView alloc] initWithFrame:CGRectMake(0, yy+globalStatusHeight+100, DEVICE_WIDTH, DEVICE_HEIGHT-yy-globalStatusHeight-100)];
    tblHistoryList.delegate = self;
    tblHistoryList.dataSource= self;
    tblHistoryList.backgroundColor = UIColor.clearColor;
    tblHistoryList.separatorStyle = UITableViewCellSelectionStyleNone;
    tblHistoryList.hidden = false;
    tblHistoryList.scrollEnabled = false;
    tblHistoryList.separatorColor = UIColor.clearColor;
    [self.view addSubview:tblHistoryList];
    
}
#pragma mark- UITableView Methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return  7; // array have to pass
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellReuseIdentifier = @"cellIdentifier";
        HomeCell *cell = [tableView dequeueReusableCellWithIdentifier:cellReuseIdentifier];
        if (cell == nil)
        {
            cell = [[HomeCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellReuseIdentifier];
        }
    
    [cell.swSocket addTarget:self action:@selector(switchSocketStateClick:) forControlEvents:UIControlEventValueChanged];
    cell.lblDeviceName.text = @"Chethan data";
    cell.lblAddress.hidden = true;
    cell.lblConnect.hidden = true;
    cell.swSocket.hidden = false;
    cell.imgSwitch.hidden = false;

    cell.lblDeviceName.frame = CGRectMake(80, 0, DEVICE_WIDTH-30, 50);
    cell.lblBack.frame = CGRectMake(5, 0, DEVICE_WIDTH-10, 50);
    cell.lblBack.backgroundColor = UIColor.clearColor;
    cell.lblBack.layer.borderColor = UIColor.whiteColor.CGColor; // light graycolor
    cell.lblBack.layer.borderWidth = .6;
    cell.lblBack.layer.cornerRadius = 6;
    cell.lblDeviceName.textColor = UIColor.whiteColor;
    cell.btnAlaram.hidden = false;
    [cell.btnAlaram addTarget:self action:@selector(btnAlarmClick:) forControlEvents:UIControlEventTouchUpInside];
    cell.btnAlaram.tag = indexPath.row;
    
    
    if (indexPath.row == 0)
       {
           cell.lblDeviceName.text = @"Socket 1";
           cell.swSocket.tag = 101;
           
           if ([[dictFromHomeSwState valueForKey:@"Switch1"] isEqual:@"01"])
           {
               [cell.swSocket setOn:YES animated:YES];
           }
           else
           {
               [cell.swSocket setOn:NO animated:YES];
           }
       }
    else if(indexPath.row == 1)
      {
        cell.lblDeviceName.text = @"Socket 2";
        cell.swSocket.tag = 102;
          if ([[dictFromHomeSwState valueForKey:@"Switch2"] isEqual:@"01"])
          {
              [cell.swSocket setOn:YES animated:YES];
          }
          else
          {
              [cell.swSocket setOn:NO animated:YES];
          }
      }
    else if(indexPath.row == 2)
      {
        cell.lblDeviceName.text = @"Socket 3";
        cell.swSocket.tag = 103;
        if ([[dictFromHomeSwState valueForKey:@"Switch3"] isEqual:@"01"])
       {
           [cell.swSocket setOn:YES animated:YES];
       }
       else
       {
           [cell.swSocket setOn:NO animated:YES];
       }
    }
    else if(indexPath.row == 3)
        {
          cell.lblDeviceName.text = @"Socket 4";
          cell.swSocket.tag = 104;
            
            if ([[dictFromHomeSwState valueForKey:@"Switch4"] isEqual:@"01"])
            {
                [cell.swSocket setOn:YES animated:YES];
            }
            else
            {
                [cell.swSocket setOn:NO animated:YES];
            }
        }
    else if(indexPath.row == 4)
      {
        cell.lblDeviceName.text = @"Socket 5";
        cell.swSocket.tag = 105;
          
          if ([[dictFromHomeSwState valueForKey:@"Switch5"] isEqual:@"01"])
          {
              [cell.swSocket setOn:YES animated:YES];
          }
          else
          {
              [cell.swSocket setOn:NO animated:YES];
          }
      }
    else if(indexPath.row == 5)
      {
        cell.lblDeviceName.text = @"Socket 6";
        cell.swSocket.tag = 106;

          if ([[dictFromHomeSwState valueForKey:@"Switch6"] isEqual:@"01"])
          {
              [cell.swSocket setOn:YES animated:YES];
          }
          else
          {
              [cell.swSocket setOn:NO animated:YES];
          }
      }
    else if (indexPath.row == 6)
    {
        cell.lblDeviceName.text = @"All sockets ON/OFF";
        cell.swSocket.tag = 107;
        cell.imgSwitch.hidden = true;
        cell.lblDeviceName.frame = CGRectMake(10, 0, DEVICE_WIDTH-20, 50);
        cell.btnAlaram.hidden = true;
    }
    cell.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}
#pragma mark- =====================
#pragma mark- Socket Switch Status...
#pragma mark- =====================
-(void)switchSocketStateClick:(id)sender
{
    UISwitch* RecntSwitch = [[UISwitch alloc] init];
    RecntSwitch = (UISwitch *)sender; // UISwitch *RecntSwitch
    
    long intTagval = RecntSwitch.tag ;
    NSLog(@"%ld",(long)intTagval);
    
    NSString * strTopic = [NSString stringWithFormat:@"/vps/device/%@",[strMacAddress uppercaseString]]; // going from device
    NSString * strSlectedIndex = [NSString stringWithFormat:@"%ld",intTagval - 101];
        NSInteger intIndex = [strSlectedIndex integerValue];
        NSData * dataIndex = [[NSData alloc] initWithBytes:&intIndex length:1];

    int index = [strSlectedIndex intValue];
    int SwitcState = 00;
    
    if ([RecntSwitch isOn])
    {
        SwitcState = 01;
    }
    
//    NSInteger intOpCode = [@"10" integerValue];
//    NSData * dataOpcode = [[NSData alloc] initWithBytes:&intOpCode length:1];
//
//    NSInteger intLength = [@"01" integerValue];
//    NSData * dataLength = [[NSData alloc] initWithBytes:&intLength length:1];
    
    NSInteger switchStatus = [@"00" integerValue];

    if ([RecntSwitch isOn])
    {
        switchStatus = [@"01" integerValue];
    }
    
    NSData * dataSwitchStatus = [[NSData alloc] initWithBytes:&switchStatus length:1];
    
    NSMutableData *completeData = [dataIndex mutableCopy];
//    [completeData appendData:dataLength];
    [completeData appendData:dataSwitchStatus];
    
    NSInteger intPacket = [@"0" integerValue];
    NSData * dataPacket = [[NSData alloc] initWithBytes:&intPacket length:1];


    NSString * strIndex = [NSString stringWithFormat:@"%02ld",intTagval - 101];
    
        if (classPeripheral.state  == CBPeripheralStateConnected)
        {
            if ([strIndex  isEqual: @"06"])
                {
                    [[BLEService sharedInstance] WriteSocketData:dataSwitchStatus withOpcode:@"10" withLength:@"1" withPeripheral:classPeripheral];
                    [[BLEService sharedInstance] WriteSocketData:dataPacket withOpcode:@"05" withLength:@"00" withPeripheral:classPeripheral];
                }
                else
                {
                    [[BLEService sharedInstance] WriteSocketData:completeData withOpcode:@"09" withLength:@"2" withPeripheral:classPeripheral];
                    [[BLEService sharedInstance] WriteSocketData:dataPacket withOpcode:@"05" withLength:@"00" withPeripheral:classPeripheral];
                }
            }
            else
            {
                if ([strIndex  isEqual: @"06"])
                {
                    NSArray * tmaprr1 =[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:10],[NSNumber numberWithInt:2],[NSNumber numberWithInt:SwitcState], nil];
                    CocoaMQTTMessage * msg = [[CocoaMQTTMessage alloc] initWithTopic:strTopic payload:tmaprr1 qos:2 retained:NO dup:NO];
                    [classMqttObj publish:msg];
        
                    NSLog(@"=============Topic======%@",msg);
                    NSLog(@"=============Packet======%@",tmaprr1);
                }
            else
            {
                NSArray * tmaprr1 =[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:9],[NSNumber numberWithInt:2],[NSNumber numberWithInt:index],[NSNumber numberWithInt:SwitcState], nil];
                CocoaMQTTMessage * msg = [[CocoaMQTTMessage alloc] initWithTopic:strTopic payload:tmaprr1 qos:2 retained:NO dup:NO];
                [classMqttObj publish:msg];
        
                NSLog(@"=============Topic======%@",msg);
                NSLog(@"=============Packet======%@",tmaprr1);
            }
    }
}
#pragma mark-Buttons
-(void)btnBackClick
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DeviceDidConnectNotificationSocket" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DeviceDidDisConnectNotificationSocket" object:nil];

    [self.navigationController popViewControllerAnimated:true];
}

-(void)btnAlarmClick:(UIButton *)sender
{
    globalSocketAlarmVC  = [[SocketAlarmVC alloc] init];
    globalSocketAlarmVC.intSelectedSwitch = sender.tag + 1; 
    globalSocketAlarmVC.periphPass = classPeripheral;
    globalSocketAlarmVC.strMacaddress  = strMacAddress;
    [self.navigationController pushViewController:globalSocketAlarmVC animated:true];
}
-(NSString*)stringFroHex:(NSString *)hexStr
{
    unsigned long long startlong;
    NSScanner* scanner1 = [NSScanner scannerWithString:hexStr];
    [scanner1 scanHexLongLong:&startlong];
    double unixStart = startlong;
    NSNumber * startNumber = [[NSNumber alloc] initWithDouble:unixStart];
    return [startNumber stringValue];
}
-(NSString*)hexFromStr:(NSString*)str
{
    NSData* nsData = [str dataUsingEncoding:NSUTF8StringEncoding];
    const char* data = [nsData bytes];
    NSUInteger len = nsData.length;
    NSMutableString* hex = [NSMutableString string];
    for(int i = 0; i < len; ++i)
        [hex appendFormat:@"%02X", data[i]];
    NSLog(@"HEX valueeeee====>>>%@",hex);
    return hex;
}
-(void)setupForSettingPicker
{
    viewBGPicker = [[UIView alloc] initWithFrame:CGRectMake(0, DEVICE_HEIGHT, DEVICE_WIDTH, 250)];
    [viewBGPicker setBackgroundColor:[UIColor whiteColor]];
    [self.view addSubview:viewBGPicker];

    datePicker = [[UIDatePicker alloc] init];
    datePicker.frame = CGRectMake(5, 45, DEVICE_WIDTH-10, 200); // set frame as your need
    datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    datePicker.backgroundColor = UIColor.whiteColor;
    [datePicker addTarget:self action:@selector(dateChanged) forControlEvents:UIControlEventValueChanged];
    [viewBGPicker addSubview: datePicker];
    
    btnCancel = [[UIButton alloc]init];
    btnCancel.frame = CGRectMake(5, 0, DEVICE_WIDTH/2-5, 44);
    [btnCancel addTarget:self action:@selector(btnCancel) forControlEvents:UIControlEventTouchUpInside];
    [btnCancel setTitle:@"Cancel" forState:normal];
    [btnCancel setTitleColor:UIColor.blackColor forState:normal];
    btnCancel.backgroundColor = UIColor.clearColor;
    btnCancel.layer.borderWidth = 0.7;
    btnCancel.layer.borderColor = UIColor.blackColor.CGColor;
    btnCancel.layer.cornerRadius = 12;
    btnCancel.titleLabel.font = [UIFont fontWithName:CGRegular size:textSizes];
    [viewBGPicker addSubview:btnCancel];
    
    UIButton * btnDone = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnDone setFrame:CGRectMake(DEVICE_WIDTH/2+5 , 0, DEVICE_WIDTH/2-10, 44)];
//    [btnDone setBackgroundImage:[UIImage imageNamed:@"BTN.png"] forState:UIControlStateNormal];
    [btnDone setTitle:@"Done" forState:UIControlStateNormal];
    [btnDone setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    btnDone.titleLabel.font = [UIFont fontWithName:CGRegular size:textSizes];
    btnDone.layer.borderWidth = 0.7;
    btnDone.layer.borderColor = UIColor.blackColor.CGColor;
    btnDone.layer.cornerRadius = 12;
    [btnDone addTarget:self action:@selector(btnDoneClicked) forControlEvents:UIControlEventTouchUpInside];
    [viewBGPicker addSubview:btnDone];
    
    
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^
    {
        self->viewBGPicker.frame = CGRectMake(0, (DEVICE_HEIGHT-200)/2, DEVICE_WIDTH, 200);
    }
                    completion:NULL];
}
-(void)btnDoneClicked
{
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^
    {
    self-> viewBGPicker.frame = CGRectMake(0, DEVICE_HEIGHT, DEVICE_WIDTH, 200);
    }
        completion:(^(BOOL finished)
      {
        [self-> datePicker removeFromSuperview];
    })];
    
    [tblHistoryList reloadData];
   }
-(void)btnCancel
{
    selectedDate = @"";
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^
    {
    self-> viewBGPicker.frame = CGRectMake(0, DEVICE_HEIGHT, DEVICE_WIDTH, 200);
    }
        completion:(^(BOOL finished)
      {
        [self-> datePicker removeFromSuperview];
    })];
}
-(void)btnSaveClick
{
  if ([txtRouterPassword.text isEqual:@""])
    {
        [self TostNotification:@"Please enter Wi-Fi password"];
    }
    else
    {
        [APP_DELEGATE startHudProcess:@"Processing..."];
        // MQTT request to device here 13 for ssid  14 for password and IP = @"13.57.255.95"
        if ([APP_DELEGATE isNetworkreachable])
        {
            //Writing SSID Name
            NSString * strHexSSID = [self hexFromStr:strSSID];
            NSData * ssidNSData = [self dataFromHexString:strHexSSID];
            [[BLEService sharedInstance] WriteSocketData:ssidNSData withOpcode:@"13" withLength:[NSString stringWithFormat:@"%d",strSSID.length] withPeripheral:globalSocketPeripheral];

            //Writing Password
            NSString * strHexPassword = [self hexFromStr:txtRouterPassword.text];
            NSData * passwordData = [self dataFromHexString:strHexPassword];
            [[BLEService sharedInstance] WriteSocketData:passwordData withOpcode:@"14" withLength:[NSString stringWithFormat:@"%d",txtRouterPassword.text.length] withPeripheral:globalSocketPeripheral];

            [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^
            {
            self-> viewForTxtBg.frame = CGRectMake(20, DEVICE_HEIGHT, DEVICE_WIDTH-40, 250);
            }
                completion:(^(BOOL finished)
              {
                [self-> viewTxtfld removeFromSuperview];
            })];
        }
        else
        {
//            [self TostNotification:@"Please connect to the internet."];
        }
    }
}
-(void)btnNotNowClick
{
    [self TostNotification:@"Now you can only Control through Bluetooth"];
    
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^
     {
    self-> viewForTxtBg.frame = CGRectMake(20, DEVICE_HEIGHT, DEVICE_WIDTH-40, 250);
     }
        completion:(^(BOOL finished)
      {
        [self-> viewTxtfld removeFromSuperview];
    })];
}
- (void)dateChanged
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd/MM/yyyy hh:mm a"];
    NSString *currentTime = [dateFormatter stringFromDate:datePicker.date];
    NSLog(@"Selected Date From user==>>%@", currentTime);
    
    selectedDate = currentTime;
    [tblHistoryList reloadData];
    if (classPeripheral.state == CBPeripheralStateConnected)
    {
      
    }
}
#pragma mark- PickerView
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView;
{
    return 1;
}
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return 1;
}
//- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
//{
//     return [arrayPickr objectAtIndex:row];
//}
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel* pickerLabel = (UILabel*)view;
    
//    [pickerLabel setText: ];
    return pickerLabel;
}
-(NSData *)StringToNSDtatConvert:(NSString *)strData
{
   NSData * data = [strData dataUsingEncoding:NSUTF8StringEncoding];
    return data;
}
#pragma mark- Setup For testFielld
-(void)SetupForTExtFieldPOPup
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
    
        self->viewForTxtBg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DEVICE_WIDTH, DEVICE_HEIGHT)];
        self->viewForTxtBg .backgroundColor = UIColor.cyanColor;
//    viewForTxtBg.alpha = 0.8;
        [self.view addSubview:self->viewForTxtBg];
    
        self->viewTxtfld = [[UIView alloc] initWithFrame:CGRectMake(20, DEVICE_HEIGHT, DEVICE_WIDTH-40, 250)];
        self->viewTxtfld .backgroundColor = UIColor.blueColor;
        self->viewTxtfld.layer.cornerRadius = 6;
        self->viewTxtfld.alpha = 0.8;
        self->viewTxtfld.clipsToBounds = true;
        [self->viewForTxtBg addSubview:self->viewTxtfld];
    
        UILabel * lblHint = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self->viewTxtfld.frame.size.width, 40)];
        lblHint.text = @"Please Enter details to connect Device with internet";
        lblHint.textColor = UIColor.whiteColor;
//    lblHint.backgroundColor = UIColor.lightGrayColor;
        lblHint.textAlignment = NSTextAlignmentCenter;
        lblHint.numberOfLines = 0;
        lblHint.font = [UIFont fontWithName:CGRegular size:textSizes];
        [self->viewTxtfld addSubview:lblHint];
    
        int yy = 00;
        self->txtDeviceName = [[UITextField alloc] initWithFrame:CGRectMake(10, yy, self->viewTxtfld.frame.size.width-20, 50)];
        [self setTextfieldProperties:self->txtDeviceName withPlaceHolderText:@"Decive name" withtextSizes:textSizes];
        self->txtDeviceName.returnKeyType = UIReturnKeyNext;
//    [viewTxtfld addSubview:txtDeviceName];
    
        yy = yy+50;
        self->txtRouterName = [[UITextField alloc] initWithFrame:CGRectMake(10, yy, self->viewTxtfld.frame.size.width-20, 50)];
        [self setTextfieldProperties:self->txtRouterName withPlaceHolderText:@"Wi-Fi Name (Wi-Fi SSID)" withtextSizes:textSizes];
        self->txtRouterName.returnKeyType = UIReturnKeyNext;
        [self->viewTxtfld addSubview:self->txtRouterName];
     
        yy = yy+60;
        self->txtRouterPassword = [[UITextField alloc] initWithFrame:CGRectMake(10, yy, self->viewTxtfld.frame.size.width-20, 50)];
        [self setTextfieldProperties:self->txtRouterPassword withPlaceHolderText:@"Wi-Fi Password" withtextSizes:textSizes];
        self->txtRouterPassword.returnKeyType = UIReturnKeyDone;
        [self->viewTxtfld addSubview:self->txtRouterPassword];
    
        UIButton *  btnNotNow = [[UIButton alloc]init];
            btnNotNow.frame = CGRectMake(0, self->viewTxtfld.frame.size.height-50, self->viewTxtfld.frame.size.width/2-5, 50);
        [btnNotNow addTarget:self action:@selector(btnNotNowClick) forControlEvents:UIControlEventTouchUpInside];
        [btnNotNow setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btnNotNow.backgroundColor = UIColor.whiteColor;
        [btnNotNow setTitle:@"Not now" forState:normal];
        [btnNotNow setTitleColor:UIColor.blueColor forState:normal];
        btnNotNow.titleLabel.font = [UIFont fontWithName:CGRegular size:textSizes];
            [self->viewTxtfld addSubview:btnNotNow];
    
    
        UIButton *  btnSave = [[UIButton alloc]init];
            btnSave.frame = CGRectMake(self->viewTxtfld.frame.size.width/2, self->viewTxtfld.frame.size.height-50, self->viewTxtfld.frame.size.width/2, 50);
        [btnSave addTarget:self action:@selector(btnSaveClick) forControlEvents:UIControlEventTouchUpInside];
        [btnSave setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btnSave.backgroundColor = UIColor.whiteColor;
        [btnSave setTitle:@"Save" forState:normal];
        [btnSave setTitleColor:UIColor.blueColor forState:normal];
        btnSave.titleLabel.font = [UIFont fontWithName:CGRegular size:textSizes];
            [self->viewTxtfld addSubview:btnSave];
        
    
    [UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^
    {
        self->viewTxtfld.frame = CGRectMake(20, (DEVICE_HEIGHT-250)/2, DEVICE_WIDTH-40, 250);
    }
        completion:NULL];
    });
}
#pragma mark-textField and Lables And Button Properties
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
-(void)TostNotification:(NSString *)StrToast
{
        dispatch_async(dispatch_get_main_queue(), ^{
            [APP_DELEGATE endHudProcess];
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];

            // Configure for text only and offset down
            hud.mode = MBProgressHUDModeText;
            hud.labelText = StrToast;
            hud.margin = 10.f;
            hud.yOffset = 150.f;
            hud.removeFromSuperViewOnHide = YES;
            hud.labelFont = [UIFont fontWithName:CGRegular size:10];
            [hud hide:YES afterDelay:0.4];
        });
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
    strValid = [strValid stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    
    return strValid;
}
-(void)ReceiveAllSoketONOFFState:(NSString *)strState
{
    dispatch_async(dispatch_get_main_queue(),
                   ^{
        self->strAllSwSatate = strState;
    });
}
-(void)ReceivedSwitchStatusfromDevice:(NSMutableDictionary *)dictSwitch;
{
    [APP_DELEGATE endHudProcess];
    dictFromHomeSwState = dictSwitch;
    [tblHistoryList reloadData];
}
-(void)ReceivedMQTTStatus:(NSDictionary *)dictSwitch
{
    
}
-(void)ConnecttoMQTTSocketServer
{
    NSMutableArray * tmpArr = [[NSMutableArray alloc] init];
    NSString * str = [NSString stringWithFormat:@"Select * from Device_Table where device_type = '4' and wifi_configured = '1'"];
    [[DataBaseManager dataBaseManager] execute:str resultsArray:tmpArr];
    
    if ([tmpArr count] > 0)
    {
        classMqttObj = [[CocoaMQTT alloc] initWithClientID:@"ClientId" host:@"iot.vithamastech.com" port:8883];
        classMqttObj.delegate = self;
        [classMqttObj selfSignedSSLSetting];
        BOOL isConnected =  [classMqttObj connect];
        if (isConnected)
        {
            NSLog(@"MQTT is CONNECTING....");
        }
    }
}
#pragma mark - MQTT Delegate Methods
-(void)mqtt:(CocoaMQTT *)mqtt didReceive:(SecTrustRef)trust completionHandler:(void (^)(BOOL))completionHandler
{
    NSLog(@"Trust==%@",trust);
    if (completionHandler)
    {
        completionHandler(YES);
    }
}
-(void)mqtt:(CocoaMQTT *)mqtt didConnectAck:(enum CocoaMQTTConnAck)ack
{
    
    NSString * publishTopic = [NSString stringWithFormat:@"/vps/device/%@",strMacAddress];
    UInt16 subTop = [mqtt subscribe:publishTopic qos:2];
    NSLog(@"%d",subTop);
    NSLog(@"MQTT Connected --->");
}
-(void)mqtt:(CocoaMQTT *)mqtt didPublishMessage:(CocoaMQTTMessage *)message id:(uint16_t)id
{
    NSArray * arrAck = [message payload];
    if([arrAck count]>0)
    {
        NSString * strAck = [arrAck componentsJoinedByString:@","];
        NSLog(@"mqtt didPublishMessage =%@",strAck);
    }
}
-(void)mqtt:(CocoaMQTT *)mqtt didPublishAck:(uint16_t)id
{
}
-(void)mqtt:(CocoaMQTT *)mqtt didReceiveMessage:(CocoaMQTTMessage *)message id:(uint16_t)id
{
    //Whenever message received we will send it to socketdtailvc.
    NSLog(@"mqtt didReceiveMessage =%@",message);
//    NSArray * arrReceive = [message payload];
}
-(void)mqtt:(CocoaMQTT *)mqtt didSubscribeTopic:(NSArray<NSString *> *)topics
{
    NSLog(@"Topic Subscried successfully =%@",topics);
    
    NSString * publishTopic = [NSString stringWithFormat:@"/vps/device/%@",strMacAddress];
    
    UInt16 pubTop =  [classMqttObj publish:publishTopic withString:@"Message" qos:2 retained:false dup:false];
    NSLog(@"%d",pubTop);
}
-(void)mqtt:(CocoaMQTT *)mqtt didUnsubscribeTopic:(NSString *)topic
{
    NSLog(@"Topic didUnsubscribeTopic =%@",topic);
}
-(void)mqtt:(CocoaMQTT *)mqtt didStateChangeTo:(enum CocoaMQTTConnState)state
{
    NSLog(@"State Changed===>%hhu",state);
}
-(void)mqttDidDisconnect:(CocoaMQTT *)mqtt withError:(NSError *)err
{
    NSLog(@"Disconnect Errore===>%@",err.description);
}
-(void)mqttDidPing:(CocoaMQTT *)mqtt
{
    
}
-(void)mqttDidReceivePong:(CocoaMQTT *)mqtt
{
    
}


-(void)DeviceDidConnectNotification:(NSNotification*)notification //Connect periperal
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [APP_DELEGATE endHudProcess];
        
        if (classPeripheral.state == CBPeripheralStateConnected)
        {
            NSInteger intPacket = [@"0" integerValue];
            NSData * dataPacket = [[NSData alloc] initWithBytes:&intPacket length:1];
            [[BLEService sharedInstance] WriteSocketData:dataPacket withOpcode:@"05" withLength:@"00" withPeripheral:classPeripheral];

        }

//        [self->tblDeviceList reloadData];
    });
}
-(void)DeviceDidDisConnectNotification:(NSNotification*)notification //Disconnect periperal
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [APP_DELEGATE endHudProcess];
        [[[BLEManager sharedManager] arrBLESocketDevices] removeAllObjects];
        [[BLEManager sharedManager] rescan];
//        [self->tblDeviceList reloadData];
        [APP_DELEGATE endHudProcess];});
}
-(void)AuthenticationCompleted:(CBPeripheral *)peripheral
{
    globalSocketPeripheral = peripheral;
    //Here you have to ask for device name... Save click call SAVE DEVICE API and save it to database.
    //After that Ask user to whether they want wifi configration.
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
-(void)AlarmListStoredinDevice:(NSMutableDictionary *)arrDictDetails
{
    [arrAlarmIdsofDevices addObject:arrDictDetails];
    
    if ([arrAlarmIdsofDevices count] >= 12)
    {
        dispatch_async(dispatch_get_main_queue(), ^(void)
        {
            NSMutableArray * arrdata = [[NSMutableArray alloc] init];
            NSString * strQuery = [NSString stringWithFormat:@"select * from Socket_Alarm_Table  where ble_address = '%@' ",strMacAddress];
            [[DataBaseManager dataBaseManager] execute:strQuery resultsArray:arrdata];
            
            for (int i = 0; i < [arrAlarmIdsofDevices count]; i++)
            {
                NSString * strAlarmId = [self stringFroHex:[[arrAlarmIdsofDevices objectAtIndex:i] valueForKey:@"alaramID"]];
                NSString * strsocketID = [[arrAlarmIdsofDevices objectAtIndex:i] valueForKey:@"socketID"];
                NSString * strdayValue = [[arrAlarmIdsofDevices objectAtIndex:i] valueForKey:@"dayValue"];
                NSString * strOnTime = [self stringFroHex:[[arrAlarmIdsofDevices objectAtIndex:i] valueForKey:@"onTime"]];
                
                NSString * strOffTime = [self stringFroHex:[[arrAlarmIdsofDevices objectAtIndex:i] valueForKey:@"offTime"]];
                NSString * stralarmState = [[arrAlarmIdsofDevices objectAtIndex:i] valueForKey:@"alarmState"];
                
                if ([arrdata count] == 0)
                {
                    if (![[[arrAlarmIdsofDevices objectAtIndex:i] valueForKey:@"alaramID"] isEqual:@"0"])
                    {
                        NSString * strInsert  =[NSString stringWithFormat:@"insert into 'Socket_Alarm_Table'('alarm_id','socket_id','day_value','OnTimestamp','OffTimestamp','alarm_state','ble_address') values('%@','%@','%@','%@','%@','%@','%@')",strAlarmId,strsocketID,strdayValue,strOnTime,strOffTime,stralarmState,strMacAddress];
                        [[DataBaseManager dataBaseManager] execute:strInsert];

                    }
                }
                else
                {
                    if (![[[arrAlarmIdsofDevices objectAtIndex:i] valueForKey:@"alaramID"] isEqual:@"0"])
                    {
                        NSString * update = [NSString stringWithFormat:@"update Socket_Alarm_Table set alarm_id = '%@', socket_id ='%@',day_value='%@', onTimestamp ='%@', offTimestamp = '%@', alarm_state = '%@' where ble_address = '%@' and alarm_id = '%@'",strAlarmId,strsocketID,strdayValue,strOnTime,strOffTime,stralarmState,strMacAddress,[[arrAlarmIdsofDevices objectAtIndex:i] valueForKey:@"alaramID"]];
                        [[DataBaseManager dataBaseManager] execute:update];

                    }
                }
            }
        });
    }
}

@end
