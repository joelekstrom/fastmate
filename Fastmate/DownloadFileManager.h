#import <Foundation/Foundation.h>

@interface DownloadFileManager : NSObject

+ (BOOL)fileExists:(NSString *)filePath;
+ (long long)getFileSize:(NSString *)filePath ;
+ (BOOL)moveFile:(NSString *)fromPath toPath:(NSString *)toPath ;
+ (BOOL)removeFile:(NSString *)filePath ;
+ (BOOL)createDirection:(NSString *)directPath;
+ (NSString *)nextAvailableFilenameAtPath:(NSString *)aPath proposedFilename:(NSString *)aName;

@end
