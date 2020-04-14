//
//  KJRequestManager.h
//  KJBleSDK
//
//  Created by apple on 2019/11/26.
//  Copyright © 2019 CoderYS. All rights reserved.
//

#import <Foundation/Foundation.h>

// 成功回调
typedef void(^KJSuccessBlock)(NSURLResponse *response, id responseObject);

// 失败回调
typedef void(^KJFailureBlock)(NSURLResponse *response, NSError * error);

@interface KJRequestManager : NSObject

// GET
+ (void)getWithUrl:(NSString *)url
            params:(NSDictionary *)params
           success:(KJSuccessBlock)success
           failure:(KJFailureBlock)failure;

// POST
+ (void)postWithUrl:(NSString *)url
             params:(NSDictionary *)params
            success:(KJSuccessBlock)success
            failure:(KJFailureBlock)failure;

@end

