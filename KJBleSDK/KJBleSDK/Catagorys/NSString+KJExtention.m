//
//  NSString+KJExtention.m
//  NSString
//
//  Created by apple on 2019/11/26.
//  Copyright © 2019 CoderYS. All rights reserved.
//

#import "NSString+KJExtention.h"

@implementation NSString (KJExtention)

- (BOOL)isNotEmpty {
    
    return ((![self isEqualToString:@""])&&(self!= nil) && [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length > 0&&(NSNull *)self!=[NSNull null]);
}

@end
