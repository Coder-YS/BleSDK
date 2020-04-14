//
//  KJRequestManager.m
//  KJBleSDK
//
//  Created by apple on 2019/11/26.
//  Copyright © 2019 CoderYS. All rights reserved.
//

#import "KJRequestManager.h"

@implementation KJRequestManager

// GET
+ (void)getWithUrl:(NSString *)url
            params:(NSDictionary *)params
           success:(KJSuccessBlock)success
           failure:(KJFailureBlock)failure {
    
    NSMutableString *mutableUrl = [[NSMutableString alloc] initWithString:url];
    if ([params allKeys]) {
        [mutableUrl appendString:@"?"];
        for (id key in params) {
            NSString *value = [[params objectForKey:key] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            [mutableUrl appendString:[NSString stringWithFormat:@"%@=%@&", key, value]];
        }
    }
    NSString *urlEnCode = [[mutableUrl substringToIndex:mutableUrl.length - 1] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlEnCode]];
    NSURLSession *urlSession = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [urlSession dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            failure(response, error);
        } else {
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            success(response, dic);
        }
    }];
    [dataTask resume];
}

// POST
+ (void)postWithUrl:(NSString *)url
             params:(NSDictionary *)params
            success:(KJSuccessBlock)success
            failure:(KJFailureBlock)failure {
    
    NSMutableString *urlStr = [NSMutableString stringWithString:url];
    NSMutableString *getRequestString = [[NSMutableString alloc] init];
    if (params!=nil) {
        for (NSString *key in [params allKeys]) {
            NSString *value = [NSString stringWithFormat:@"%@",[params objectForKey:key]];
            if (getRequestString == nil || [getRequestString isEqualToString:@""]) {
                [getRequestString appendString:[NSString stringWithFormat:@"?%@=%@",key,value]];
            }else{
                [getRequestString appendString:[NSString stringWithFormat:@"&%@=%@",key,value]];
            }
        }
    }
    [urlStr appendString:getRequestString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    //如果想要设置网络超时的时间的话，可以使用下面的方法：
    //NSMutableURLRequest *mutableRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    //设置请求类型
    request.HTTPMethod = @"POST";
//    NSString *postStr = [self parseParams:parameters];
//    //把参数放到请求体内
//    request.HTTPBody = [postStr dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) { //请求失败
            failure(response ,error);
        } else {  //请求成功
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            success(response, dic);
        }
    }];
    [dataTask resume];  //开始请求
}

//把NSDictionary解析成post格式的NSString字符串
+ (NSString *)parseParams:(NSDictionary *)params {
    NSString *keyValueFormat;
    NSMutableString *result = [NSMutableString new];
    NSMutableArray *array = [NSMutableArray new];
    //实例化一个key枚举器用来存放dictionary的key
    NSEnumerator *keyEnum = [params keyEnumerator];
    id key;
    while (key = [keyEnum nextObject]) {
        keyValueFormat = [NSString stringWithFormat:@"%@=%@&", key, [params valueForKey:key]];
        [result appendString:keyValueFormat];
        [array addObject:keyValueFormat];
    }
    return result;
}


@end
