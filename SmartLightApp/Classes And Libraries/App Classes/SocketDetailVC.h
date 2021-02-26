//
//  SocketDetailVC.h
//  SmartLightApp
//
//  Created by Kalpesh Panchasara on 06/01/21.
//  Copyright © 2021 Kalpesh Panchasara. All rights reserved.
//

#import <UIKit/UIKit.h>
@import CocoaMQTT;

NS_ASSUME_NONNULL_BEGIN

@interface SocketDetailVC : UIViewController
{
    UITableView * tblHistoryList;
    int globalStatusHeight;

}
@property(nonatomic,strong)NSMutableDictionary *  deviceDetail;

@property(nonatomic,strong)NSMutableDictionary * dictFromHomeSwState1;
@property(nonatomic,strong)NSString *  isMQTTselect;
@property(nonatomic, strong) CBPeripheral * classPeripheral;
@property(nonatomic,strong) NSString *  strMacAddress;
@property(nonatomic,strong) NSString *  strWifiConnect;
@property(nonatomic, strong) CocoaMQTT * classMqttObj;
-(void)ReceiveAllSoketONOFFState:(NSString *)strState;
-(void)ReceivedSwitchStatusfromDevice:(NSMutableDictionary *)dictSwitch;
-(void)ReceivedMQTTStatus:(NSDictionary *)dictSwitch;
-(void)AlarmListStoredinDevice:(NSMutableDictionary *)dictAlList;


@end

NS_ASSUME_NONNULL_END
