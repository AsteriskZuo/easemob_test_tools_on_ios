//
//  IOSPathResolver.h
//  iOS路径解析工具类
//
//  Created on 2025-09-10.
//  Copyright © 2025. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * iOS路径类型枚举
 */
typedef NS_ENUM(NSInteger, IOSPathType) {
    IOSPathTypeUnknown = 0,           // 未知类型
    IOSPathTypeAbsolute,              // 绝对路径 (如: /var/mobile/...)
    IOSPathTypeFileURL,               // file:// URL路径
    IOSPathTypeBundleResource,        // Bundle资源路径 (如: MainBundle中的资源)
    IOSPathTypeDocuments,             // Documents目录路径
    IOSPathTypeLibrary,               // Library目录路径
    IOSPathTypeCache,                 // Cache目录路径
    IOSPathTypeTmp,                   // 临时目录路径
    IOSPathTypeApplicationSupport,    // Application Support目录路径
    IOSPathTypeRelative,             // 相对路径
    IOSPathTypeSymbolicLink,         // 符号链接
    IOSPathTypeNetworkURL            // 网络URL (http/https)
};

/**
 * 路径解析结果结构体
 */
@interface IOSPathInfo : NSObject
@property (nonatomic, assign) IOSPathType pathType;
@property (nonatomic, strong) NSString *originalPath;
@property (nonatomic, strong, nullable) NSString *resolvedPath;
@property (nonatomic, strong, nullable) NSString *canonicalPath;
@property (nonatomic, assign) BOOL exists;
@property (nonatomic, assign) BOOL isDirectory;
@property (nonatomic, assign) BOOL isReadable;
@property (nonatomic, assign) BOOL isWritable;
@property (nonatomic, strong, nullable) NSError *error;
@end

/**
 * iOS路径解析工具类
 * 支持将各种iOS平台路径转换为真实的绝对路径
 */
@interface IOSPathResolver : NSObject

/**
 * 单例方法
 */
+ (instancetype)sharedResolver;

/**
 * 解析路径并返回详细信息
 * @param inputPath 输入路径
 * @return 路径信息对象
 */
- (IOSPathInfo *)resolvePathInfo:(NSString *)inputPath;

/**
 * 将输入路径转换为真实的绝对路径
 * @param inputPath 输入路径
 * @return 真实绝对路径，失败返回nil
 */
- (nullable NSString *)resolvePath:(NSString *)inputPath;

/**
 * 检测路径类型
 * @param path 路径字符串
 * @return 路径类型枚举
 */
- (IOSPathType)detectPathType:(NSString *)path;

/**
 * 获取应用沙盒各目录的真实路径
 */
- (NSString *)documentsPath;
- (NSString *)libraryPath;
- (NSString *)cachePath;
- (NSString *)tmpPath;
- (NSString *)applicationSupportPath;
- (NSString *)bundlePath;

/**
 * Bundle资源路径解析
 * @param resourceName 资源名称 (不包含扩展名)
 * @param extension 文件扩展名
 * @param bundlePath Bundle路径，nil表示主Bundle
 * @return 资源的真实路径
 */
- (nullable NSString *)resolveResourcePath:(NSString *)resourceName
                             withExtension:(nullable NSString *)extension
                                  inBundle:(nullable NSString *)bundlePath;

/**
 * 标准化路径 (解析 . 和 .. 等)
 * @param path 输入路径
 * @return 标准化后的路径
 */
- (NSString *)normalizePath:(NSString *)path;

/**
 * 解析符号链接
 * @param path 可能包含符号链接的路径
 * @return 解析后的真实路径
 */
- (nullable NSString *)resolveSymbolicLink:(NSString *)path;

/**
 * 路径类型转字符串
 * @param pathType 路径类型
 * @return 类型描述字符串
 */
- (NSString *)pathTypeDescription:(IOSPathType)pathType;

@end

NS_ASSUME_NONNULL_END
