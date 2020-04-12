#import "KVOBlockObserver.h"

@interface KVOBlockObserver()
@property (nonatomic, weak) id object;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, copy) void (^block)(id);
@property (nonatomic, readwrite) void *context;
@end

@implementation KVOBlockObserver

- (instancetype)initWithObject:(id)object keyPath:(NSString *)keyPath block:(void (^)(id value))block {
    if (self == [super init]) {
        _object = object;
        _context = (__bridge void *)(self);
        _block = block;
        _keyPath = keyPath;
        [object addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:_context];
    }
    return self;
}

- (instancetype)initWithObject:(id)object keyPath:(NSString *)keyPath boolBlock:(void (^)(BOOL))block {
    return [self initWithObject:object keyPath:keyPath block:^(id  _Nonnull value) {
        block([value boolValue]);
    }];
}

+ (instancetype)observe:(id)object keyPath:(NSString *)keyPath block:(void (^)(id _Nonnull))block {
    block([object valueForKeyPath:keyPath]);
    return [[self alloc] initWithObject:object keyPath:keyPath block:block];
}

+ (instancetype)observe:(id)object keyPath:(NSString *)keyPath boolBlock:(void (^)(BOOL))block {
    block([[object valueForKeyPath:keyPath] boolValue]);
    return [[self alloc] initWithObject:object keyPath:keyPath block:^(id  _Nonnull value) {
        block([value boolValue]);
    }];
}

+ (instancetype)observeUserDefaultsKey:(NSString *)key block:(void (^)(BOOL))block {
    return [self observe:NSUserDefaults.standardUserDefaults keyPath:key boolBlock:block];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == self.context) {
        self.block(change[NSKeyValueChangeNewKey]);
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)dealloc {
    [self.object removeObserver:self forKeyPath:self.keyPath context:self.context];
}

@end
