//
//  TokenBuilder.m
//  sdkTest
//
//  Created by li xiaoming on 2023/12/12.
//

#import "TokenBuilder.h"
#import "ChatTokenBuilder2.h"
#import <HyphenateChat/HyphenateChat.h>

@implementation TokenBuilder
+ (NSString *)buildTokenWithAppId:(NSString*)appId
                             cert:(NSString*)cert
                           userId:(NSString*)userId
                      expiredTime:(uint32_t)timestamp
{
    std::string token = agora::tools::ChatTokenBuilder2::BuildUserToken(appId.UTF8String, cert.UTF8String, userId.UTF8String,timestamp);
    return [NSString stringWithUTF8String:token.c_str()];
}

+ (NSString*)_uploadFileData:(NSData *)aData
               fileName:(NSString *)aFileName
{
    NSString *filePath = NSHomeDirectory();
    filePath = [NSString stringWithFormat:@"%@/Library/appdata/files", filePath];
    NSFileManager *fm = [NSFileManager defaultManager];
    if(![fm fileExistsAtPath:filePath]) {
        [fm createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    if ([aFileName length] > 0) {
        filePath = [NSString stringWithFormat:@"%@/%@", filePath,  aFileName];
    } else {
        filePath = [NSString stringWithFormat:@"%@/%d%d.jpg", filePath, (int)[[NSDate date] timeIntervalSince1970], arc4random() % 100000];
    }
    
    [aData writeToFile:filePath atomically:YES];
    return filePath;
}

- (void)testCode {

}

@end
