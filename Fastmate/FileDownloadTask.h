#import <Foundation/Foundation.h>

@interface FileDownloadTask : NSObject

+ (BOOL)fileExists:(NSString *)filePath;
+ (long long)getFileSize:(NSString *)filePath ;
+ (BOOL)moveFile:(NSString *)fromPath toPath:(NSString *)toPath;
+ (BOOL)removeFile:(NSString *)filePath;
+ (NSString *)nextAvailableFilenameAtPath:(NSString *)aPath proposedFilename:(NSString *)aName;

@end
