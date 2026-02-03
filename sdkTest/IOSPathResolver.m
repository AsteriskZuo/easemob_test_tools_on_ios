//
//  IOSPathResolver.m
//  iOS路径解析工具类实现
//
//  Created on 2025-09-10.
//  Copyright © 2025. All rights reserved.
//

#import "IOSPathResolver.h"

@implementation IOSPathInfo
@end

@implementation IOSPathResolver

#pragma mark - 单例实现

+ (instancetype)sharedResolver {
    static IOSPathResolver *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - 主要解析方法

- (IOSPathInfo *)resolvePathInfo:(NSString *)inputPath {
    IOSPathInfo *info = [[IOSPathInfo alloc] init];
    info.originalPath = inputPath;
    
    if (!inputPath || inputPath.length == 0) {
        info.pathType = IOSPathTypeUnknown;
        info.error = [NSError errorWithDomain:@"IOSPathResolver" 
                                         code:-1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"输入路径为空"}];
        return info;
    }
    
    // 检测路径类型
    info.pathType = [self detectPathType:inputPath];
    
    // 解析真实路径
    info.resolvedPath = [self resolvePath:inputPath];
    
    if (info.resolvedPath) {
        // 获取规范路径
        info.canonicalPath = [self normalizePath:info.resolvedPath];
        
        // 检查文件系统属性
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        info.exists = [fileManager fileExistsAtPath:info.canonicalPath isDirectory:&isDirectory];
        info.isDirectory = isDirectory;
        
        if (info.exists) {
            info.isReadable = [fileManager isReadableFileAtPath:info.canonicalPath];
            info.isWritable = [fileManager isWritableFileAtPath:info.canonicalPath];
        }
    } else {
        info.error = [NSError errorWithDomain:@"IOSPathResolver" 
                                         code:-2 
                                     userInfo:@{NSLocalizedDescriptionKey: @"无法解析路径"}];
    }
    
    return info;
}

- (nullable NSString *)resolvePath:(NSString *)inputPath {
    if (!inputPath || inputPath.length == 0) {
        return nil;
    }
    
    IOSPathType pathType = [self detectPathType:inputPath];
    
    switch (pathType) {
        case IOSPathTypeFileURL:
            return [self resolveFileURL:inputPath];
            
        case IOSPathTypeBundleResource:
            return [self resolveBundleResourcePath:inputPath];
            
        case IOSPathTypeDocuments:
            return [self resolveDocumentsPath:inputPath];
            
        case IOSPathTypeLibrary:
            return [self resolveLibraryPath:inputPath];
            
        case IOSPathTypeCache:
            return [self resolveCachePath:inputPath];
            
        case IOSPathTypeTmp:
            return [self resolveTmpPath:inputPath];
            
        case IOSPathTypeApplicationSupport:
            return [self resolveApplicationSupportPath:inputPath];
            
        case IOSPathTypeRelative:
            return [self resolveRelativePath:inputPath];
            
        case IOSPathTypeSymbolicLink:
            return [self resolveSymbolicLink:inputPath];
            
        case IOSPathTypeAbsolute:
            return [self normalizePath:inputPath];
            
        case IOSPathTypeNetworkURL:
            // 网络URL不需要本地路径解析
            return inputPath;
            
        default:
            return [self normalizePath:inputPath];
    }
}

#pragma mark - 路径类型检测

- (IOSPathType)detectPathType:(NSString *)path {
    if (!path || path.length == 0) {
        return IOSPathTypeUnknown;
    }
    
    // 网络URL检测
    if ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"] || [path hasPrefix:@"ftp://"]) {
        return IOSPathTypeNetworkURL;
    }
    
    // file:// URL检测
    if ([path hasPrefix:@"file://"]) {
        return IOSPathTypeFileURL;
    }
    
    // 绝对路径检测
    if ([path hasPrefix:@"/"]) {
        // 检查是否为符号链接
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:nil];
        if (attributes && [attributes[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
            return IOSPathTypeSymbolicLink;
        }
        return IOSPathTypeAbsolute;
    }
    
    // Bundle资源路径检测 (通常不以/开头，包含资源名)
    if ([path containsString:@"."] && ![path containsString:@"/"]) {
        return IOSPathTypeBundleResource;
    }
    
    // 特殊目录路径检测
    if ([path hasPrefix:@"~/Documents"] || [path hasPrefix:@"Documents/"]) {
        return IOSPathTypeDocuments;
    }
    if ([path hasPrefix:@"~/Library"] || [path hasPrefix:@"Library/"]) {
        return IOSPathTypeLibrary;
    }
    if ([path hasPrefix:@"~/Cache"] || [path hasPrefix:@"Cache/"]) {
        return IOSPathTypeCache;
    }
    if ([path hasPrefix:@"~/tmp"] || [path hasPrefix:@"tmp/"]) {
        return IOSPathTypeTmp;
    }
    if ([path hasPrefix:@"~/ApplicationSupport"] || [path hasPrefix:@"ApplicationSupport/"]) {
        return IOSPathTypeApplicationSupport;
    }
    
    // 相对路径检测
    if ([path hasPrefix:@"./"] || [path hasPrefix:@"../"] || ![path hasPrefix:@"/"]) {
        return IOSPathTypeRelative;
    }
    
    return IOSPathTypeUnknown;
}

#pragma mark - 特定类型路径解析

- (NSString *)resolveFileURL:(NSString *)fileURL {
    NSURL *url = [NSURL URLWithString:fileURL];
    if (url && url.isFileURL) {
        return url.path;
    }
    return nil;
}

- (NSString *)resolveBundleResourcePath:(NSString *)resourcePath {
    NSString *name = nil;
    NSString *extension = nil;
    
    NSRange dotRange = [resourcePath rangeOfString:@"." options:NSBackwardsSearch];
    if (dotRange.location != NSNotFound) {
        name = [resourcePath substringToIndex:dotRange.location];
        extension = [resourcePath substringFromIndex:dotRange.location + 1];
    } else {
        name = resourcePath;
    }
    
    return [self resolveResourcePath:name withExtension:extension inBundle:nil];
}

- (NSString *)resolveDocumentsPath:(NSString *)path {
    NSString *documentsPath = [self documentsPath];
    if ([path hasPrefix:@"~/Documents"]) {
        return [documentsPath stringByAppendingPathComponent:[path substringFromIndex:12]];
    } else if ([path hasPrefix:@"Documents/"]) {
        return [documentsPath stringByAppendingPathComponent:[path substringFromIndex:10]];
    }
    return [documentsPath stringByAppendingPathComponent:path];
}

- (NSString *)resolveLibraryPath:(NSString *)path {
    NSString *libraryPath = [self libraryPath];
    if ([path hasPrefix:@"~/Library"]) {
        return [libraryPath stringByAppendingPathComponent:[path substringFromIndex:10]];
    } else if ([path hasPrefix:@"Library/"]) {
        return [libraryPath stringByAppendingPathComponent:[path substringFromIndex:8]];
    }
    return [libraryPath stringByAppendingPathComponent:path];
}

- (NSString *)resolveCachePath:(NSString *)path {
    NSString *cachePath = [self cachePath];
    if ([path hasPrefix:@"~/Cache"]) {
        return [cachePath stringByAppendingPathComponent:[path substringFromIndex:8]];
    } else if ([path hasPrefix:@"Cache/"]) {
        return [cachePath stringByAppendingPathComponent:[path substringFromIndex:6]];
    }
    return [cachePath stringByAppendingPathComponent:path];
}

- (NSString *)resolveTmpPath:(NSString *)path {
    NSString *tmpPath = [self tmpPath];
    if ([path hasPrefix:@"~/tmp"]) {
        return [tmpPath stringByAppendingPathComponent:[path substringFromIndex:6]];
    } else if ([path hasPrefix:@"tmp/"]) {
        return [tmpPath stringByAppendingPathComponent:[path substringFromIndex:4]];
    }
    return [tmpPath stringByAppendingPathComponent:path];
}

- (NSString *)resolveApplicationSupportPath:(NSString *)path {
    NSString *appSupportPath = [self applicationSupportPath];
    if ([path hasPrefix:@"~/ApplicationSupport"]) {
        return [appSupportPath stringByAppendingPathComponent:[path substringFromIndex:21]];
    } else if ([path hasPrefix:@"ApplicationSupport/"]) {
        return [appSupportPath stringByAppendingPathComponent:[path substringFromIndex:19]];
    }
    return [appSupportPath stringByAppendingPathComponent:path];
}

- (NSString *)resolveRelativePath:(NSString *)path {
    NSString *currentPath = [[NSFileManager defaultManager] currentDirectoryPath];
    return [currentPath stringByAppendingPathComponent:path];
}

#pragma mark - 沙盒目录路径获取

- (NSString *)documentsPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}

- (NSString *)libraryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}

- (NSString *)cachePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}

- (NSString *)tmpPath {
    return NSTemporaryDirectory();
}

- (NSString *)applicationSupportPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}

- (NSString *)bundlePath {
    return [[NSBundle mainBundle] bundlePath];
}

#pragma mark - Bundle资源解析

- (nullable NSString *)resolveResourcePath:(NSString *)resourceName 
                             withExtension:(nullable NSString *)extension 
                                  inBundle:(nullable NSString *)bundlePath {
    NSBundle *bundle = bundlePath ? [NSBundle bundleWithPath:bundlePath] : [NSBundle mainBundle];
    return [bundle pathForResource:resourceName ofType:extension];
}

#pragma mark - 路径标准化和符号链接解析

- (NSString *)normalizePath:(NSString *)path {
    return [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
}

- (nullable NSString *)resolveSymbolicLink:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString *resolvedPath = [fileManager destinationOfSymbolicLinkAtPath:path error:&error];
    
    if (resolvedPath) {
        // 如果解析出的路径是相对路径，需要相对于符号链接所在目录
        if (![resolvedPath hasPrefix:@"/"]) {
            NSString *linkDir = [path stringByDeletingLastPathComponent];
            resolvedPath = [linkDir stringByAppendingPathComponent:resolvedPath];
        }
        return [self normalizePath:resolvedPath];
    }
    
    return [self normalizePath:path];
}

#pragma mark - 工具方法

- (NSString *)pathTypeDescription:(IOSPathType)pathType {
    switch (pathType) {
        case IOSPathTypeUnknown:
            return @"未知类型";
        case IOSPathTypeAbsolute:
            return @"绝对路径";
        case IOSPathTypeFileURL:
            return @"file:// URL路径";
        case IOSPathTypeBundleResource:
            return @"Bundle资源路径";
        case IOSPathTypeDocuments:
            return @"Documents目录路径";
        case IOSPathTypeLibrary:
            return @"Library目录路径";
        case IOSPathTypeCache:
            return @"Cache目录路径";
        case IOSPathTypeTmp:
            return @"临时目录路径";
        case IOSPathTypeApplicationSupport:
            return @"Application Support目录路径";
        case IOSPathTypeRelative:
            return @"相对路径";
        case IOSPathTypeSymbolicLink:
            return @"符号链接";
        case IOSPathTypeNetworkURL:
            return @"网络URL";
        default:
            return @"未定义类型";
    }
}

@end
