//
//  TBRuntime.m
//  TBTweakViewController
//
//  Created by Tanner on 3/22/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "TBRuntime.h"
#import "Categories.h"
#import "NSObject+Reflection.h"

#define TBEquals(a, b) ([a compare:b options:NSCaseInsensitiveSearch] == NSOrderedSame)
#define TBContains(a, b) ([a rangeOfString:b options:NSCaseInsensitiveSearch].location != NSNotFound)
#define TBHasPrefix(a, b) ([a rangeOfString:b options:NSCaseInsensitiveSearch].location == 0)
#define TBHasSuffix(a, b) ([a rangeOfString:b options:NSCaseInsensitiveSearch].location == (a.length - b.length))


@interface TBRuntime ()
@property (nonatomic) NSMutableDictionary *bundles_pathToShort;
@property (nonatomic) NSMutableDictionary *bundles_pathToClassNames;
@property (nonatomic) NSMutableArray<NSString*> *imageNames;
@end

/// @return success if the map passes.
static inline NSString * TBWildcardMap_(NSString *token, NSString *candidate, NSString *success, TBWildcardOptions options) {
    switch (options) {
        case TBWildcardOptionsNone:
            // Only "if equals"
            if (TBEquals(candidate, token)) {
                return success;
            }
        default: {
            // Only "if contains"
            if (options & TBWildcardOptionsPrefix &&
                options & TBWildcardOptionsSuffix) {
                if (TBContains(candidate, token)) {
                    return success;
                }
            }
            // Only "if starts with"
            else if (options & TBWildcardOptionsPrefix) {
                if (TBHasPrefix(candidate, token)) {
                    return success;
                }
            }
            // Only "if ends with"
            else if (options & TBWildcardOptionsSuffix) {
                if (TBHasSuffix(candidate, token)) {
                    return success;
                }
            }
        }
    }

    return nil;
}

/// @return candidate if the map passes.
static inline NSString * TBWildcardMap(NSString *token, NSString *candidate, TBWildcardOptions options) {
    return TBWildcardMap_(token, candidate, candidate, options);
}

@implementation TBRuntime

#pragma mark - Initialization

+ (instancetype)runtime {
    static TBRuntime *runtime;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        runtime = [self new];
    });

    return runtime;
}

- (id)init {
    self = [super init];
    if (self) {
        _imageNames = [NSMutableArray array];
        _bundles_pathToShort = [NSMutableDictionary dictionary];
    }

    return self;
}

#pragma mark - Private

#pragma mark Binary Images

- (void)loadBinaryImages {
    unsigned int imageCount = 0;
    const char **imageNames = objc_copyImageNames(&imageCount);

    if (imageNames) {
        NSMutableArray *imageNameStrings = [NSMutableArray upto:imageCount map:^id(NSUInteger i) {
            return @(imageNames[i]);
        }];

        self.imageNames = imageNameStrings;
        free(imageNames);

        // Sort alphabetically
        [imageNameStrings sortUsingComparator:^NSComparisonResult(NSString *name1, NSString *name2) {
            NSString *shortName1 = [self shortNameForImageName:name1];
            NSString *shortName2 = [self shortNameForImageName:name2];
            return [shortName1 caseInsensitiveCompare:shortName2];
        }];
    }
}

- (NSString *)shortNameForImageName:(NSString *)imageName {
    // Cache
    NSString *shortName = _bundles_pathToShort[imageName];
    if (shortName) {
        return shortName;
    }

    NSArray *components = [imageName componentsSeparatedByString:@"/"];
    if (components.count >= 2) {
        NSString *parentDir = components[components.count - 2];
        if ([parentDir hasSuffix:@".framework"]) {
            shortName = parentDir;
        }
    }

    if (!shortName) {
        shortName = imageName.lastPathComponent;
    }

    _bundles_pathToShort[imageName] = shortName;
    return shortName;
}

#pragma mark Bundles and classes

/// Full bundle paths, not just UI strings
- (NSMutableArray<NSString*> *)_bundlesForKeyPath:(TBKeyPath *)keyPath {
    if (self.imageNames.count) {
        TBWildcardOptions options = keyPath.bundleKey.options;
        NSString *token = keyPath.bundleKey.string;

        return [self.imageNames map:^id(NSString *binary) {
            NSString *UIName = [self shortNameForImageName:binary];
            return TBWildcardMap_(token, UIName, binary, options);
        }];
    }

    return [NSMutableArray array];
}

- (NSMutableArray<NSString*> *)classNamesInImageAtPath:(NSString *)path {
    // Check cache
    NSMutableArray *classNameStrings = _bundles_pathToClassNames[path];
    if (classNameStrings) {
        return classNameStrings.mutableCopy;
    }

    unsigned int classCount = 0;
    const char **classNames = objc_copyClassNamesForImage(path.UTF8String, &classCount);

    if (classNames) {
        classNameStrings = [NSMutableArray upto:classCount map:^id(NSUInteger i) {
            return @(classNames[i]);
        }];

        free(classNames);

        [classNameStrings sortUsingSelector:@selector(caseInsensitiveCompare:)];
        _bundles_pathToClassNames[path] = classNameStrings;

        return classNameStrings.mutableCopy;
    }

    return [NSMutableArray array];
}

#pragma mark - Public

- (NSMutableArray<NSString*> *)bundlesForKeyPath:(TBKeyPath *)keyPath {
    if (self.imageNames.count) {
        TBWildcardOptions options = keyPath.bundleKey.options;
        NSString *token = keyPath.bundleKey.string;

        return [self.imageNames map:^id(NSString *binary) {
            NSString *UIName = [self shortNameForImageName:binary];
            return TBWildcardMap(token, UIName, options);
        }];
    }

    return [NSMutableArray array];
}

- (NSMutableArray<NSString*> *)classesForKeyPath:(TBKeyPath *)keyPath {
    NSMutableArray<NSString*> *bundles = [self _bundlesForKeyPath:keyPath];

    if (bundles.count) {
        TBWildcardOptions options = keyPath.classKey.options;
        NSString *token = keyPath.classKey.string;

        return [bundles flatmap:^NSArray *(NSString *bundlePath) {
            return [[self classNamesInImageAtPath:bundlePath] map:^id(NSString *className) {
                return TBWildcardMap(token, className, options);
            }];
        }];
    }

    return [NSMutableArray array];
}

- (NSMutableArray<MKMethod*> *)methodsForKeyPath:(TBKeyPath *)keyPath {
    NSMutableArray *classes = [self classesForKeyPath:keyPath];

    if (classes.count) {
        TBWildcardOptions options = keyPath.methodKey.options;
        BOOL instance = keyPath.instanceMethods.boolValue;
        NSString *selector = keyPath.methodKey.string;

        // Remove leading - or +
        if (keyPath.instanceMethods) {
            selector = [selector substringFromIndex:1];
        }

        switch (options) {
            case TBWildcardOptionsNone: {
                SEL sel = (SEL)selector.UTF8String;
                return [classes map:^id(NSString *name) {
                    Class cls = NSClassFromString(name);

                    // Method is absolute
                    return [MKMethod methodForSelector:sel implementedInClass:cls instance:instance];
                }];
            }
            default: {
                // Only "if contains"
                if (options & TBWildcardOptionsPrefix &&
                    options & TBWildcardOptionsSuffix) {
                    return [classes flatmap:^NSArray *(NSString *name) {
                        Class cls = NSClassFromString(name);
                        return [[cls allMethods] map:^id(MKMethod *method) {

                            // Method is a prefix-suffix wildcard
                            if (TBContains(method.selectorString, selector)) {
                                return method;
                            }
                            return nil;
                        }];
                    }];
                }
                // Only "if starts with"
                else if (options & TBWildcardOptionsPrefix) {
                    return [classes flatmap:^NSArray *(NSString *name) {
                        Class cls = NSClassFromString(name);
                        return [[cls allMethods] map:^id(MKMethod *method) {

                            // Method is a prefix wildcard
                            if (TBHasPrefix(method.selectorString, selector)) {
                                return method;
                            }
                            return nil;
                        }];
                    }];
                }
                // Only "if ends with"
                else if (options & TBWildcardOptionsSuffix) {
                    return [classes flatmap:^NSArray *(NSString *name) {
                        Class cls = NSClassFromString(name);
                        return [[cls allMethods] map:^id(MKMethod *method) {

                            // Method is a suffix wildcard
                            if (TBHasSuffix(method.selectorString, selector)) {
                                return method;
                            }
                            return nil;
                        }];
                    }];
                }
            }
        }
    }

    return [NSMutableArray array];
}

- (MKMethod *)methodForAbsoluteKeyPath:(TBKeyPath *)keyPath {
    if (keyPath.isAbsolute) {
        @try {
            return [self methodsForKeyPath:keyPath][0];
        } @catch (NSException *exception) {
            return nil;
        }
    }

    @throw NSInternalInconsistencyException;
    return nil;
}

@end
