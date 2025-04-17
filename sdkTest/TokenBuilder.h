//
//  TokenBuilder.h
//  sdkTest
//
//  Created by li xiaoming on 2023/12/12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TokenBuilder : NSObject
+ (NSString *)buildTokenWithAppId:(NSString*)appId
                             cert:(NSString*)cert
                           userId:(NSString*)userId
                      expiredTime:(uint32_t)timestamp;

+ (NSString*)_uploadFileData:(NSData *)aData
                    fileName:(NSString *)aFileName;
+ (void)test;
@end

NS_ASSUME_NONNULL_END
