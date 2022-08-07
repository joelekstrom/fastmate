#import "FileDownloadUtil.h"

@implementation FileDownloadUtil

+ (BOOL)fileExists:(NSString *)filePath {
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

+ (long long)getFileSize:(NSString *)filePath {
    if (![self fileExists:filePath])return 0;
    return [[[NSFileManager defaultManager] attributesOfFileSystemForPath:filePath error:nil] fileSize];
}

+(BOOL)moveFile:(NSString *)fromPath toPath:(NSString *)toPath {
    if (![self fileExists:fromPath]) return NO;
    NSError *error;
    return [[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:&error];
}

+ (BOOL)removeFile:(NSString *)filePath {
    if (![self fileExists:filePath]) return YES;
    return [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
}

+ (NSString *)nextAvailableFilenameAtPath:(NSString *)aPath proposedFilename:(NSString *)aName{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:[aPath stringByAppendingPathComponent:aName]]) {
        return aName;
    }
    unsigned int i = 1;
    NSString *extension = [aName pathExtension];
    NSString *filenameNoSuffix = [aName stringByDeletingPathExtension];
    for (;;){
        NSString *filename = [[NSString stringWithFormat:@"%@-%d", filenameNoSuffix, i++]
            stringByAppendingPathExtension:extension];
        if (![fm fileExistsAtPath:[aPath stringByAppendingPathComponent:filename]])
            return filename;
    }
    return nil;
}

@end
